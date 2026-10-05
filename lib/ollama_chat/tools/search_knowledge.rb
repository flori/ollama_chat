# Collect snippets relevant to the supplied query.
#
# This tool searches the local document collection for text that matches the
# supplied query.  It is used by the chat backend to provide an
# "in‑context" snippet set that the model can reference when answering user
# questions.  The tool performs three steps:
#
# 1. **Validate** the request – the model must be running with embeddings
#    enabled and the query cannot be empty.
# 2. **Search** – it uses `chat.documents.find_where` to locate snippets that
#    contain the query string (trimmed to the embedding model’s context length)
#    and collect tags from the snippet text.
# 3. **Return** – a JSON string containing a friendly prompt header and an
#    array of `{text, tags}` objects.  Each tag includes `name` and the
#    originating `source`.
#
# @note The tool is deliberately read‑only; it never mutates the chat or
#   the underlying document store.
class OllamaChat::Tools::SearchKnowledge
  include OllamaChat::Tools::Concern
  include Kramdown::ANSI::Width

  # @return [String] the registered name for this tool
  def self.register_name = 'search_knowledge'

  # Function‑definition that the chat system exposes to the model.
  # It follows the same pattern as other tools in the project.
  #
  # @return [Ollama::Tool] the tool definition usable by the Ollama
  #   server
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: <<~EOT,
          Search the local knowledge collections for text matching the
          supplied query. The result is a JSON string containing
          a prompt header and an array of {text, tags} objects.
        EOT
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            query: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: <<~EOT,
                The query or text to search for in the knowledge collections.
              EOT
            ),
            tags: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: <<~EOT,
                A comma-separated list of tags (e.g., 'tag1,tag2'). The search
                will be filtered to only return snippets that match at least
                one of the provided tags.
              EOT
            ),
            collection: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: <<~EOT,
                The specific knowledge collection to search in.
              EOT
            ),
            min_similarity: Tool::Function::Parameters::Property.new(
              type: 'number',
              description: <<~EOT,
                The minimum similarity score required for a snippet to be
                returned. Higher values are more restrictive.
              EOT
            ),
            text_size: Tool::Function::Parameters::Property.new(
              type: 'integer',
              description: 'The maximum size of each snippet.'
            ),
            text_count: Tool::Function::Parameters::Property.new(
              type: 'integer',
              description: 'The maximum number of snippets to return.'
            ),
            rerank: Tool::Function::Parameters::Property.new(
              type: 'boolean',
              description: 'Rerank the returned records if true, (default: true)'
            )
          },
          required: ['query']
        )
      )
    )
  end

  # Called when the model invokes the tool.
  #
  # @param tool_call [OllamaChat::Tool::Call] the tool call object
  # @return [String] JSON string with the resulting snippets, or an error
  # @raise [OllamaChat::OllamaChatError] if embeddings are disabled or query
  #   is empty
  def execute(tool_call, **opts)

    chat.embedding.on? or raise OllamaChat::OllamaChatError, 'Embedding disabled'

    args  = tool_call.function.arguments

    query = args.query.to_s
    query.blank? and raise OllamaChat::OllamaChatError, 'Empty query'
    tags           = args.tags.full?(:split, ?,)
    text_size      = args.text_size.full? || chat.config.embedding.found_texts_size?
    text_count     = args.text_count.full? || chat.config.embedding.found_texts_count?
    min_similarity = args.min_similarity.full?
    rerank         = args.rerank
    rerank         = true if rerank.nil?

    old_collection = nil

    if collection = args.collection.full?
      unless collection.to_s.match?(/\A#{OllamaChat::COLLECTION_NAME_REGEXP.source}\z/)
        raise OllamaChat::ToolFunctionArgumentError,
          "Invalid collection name: #{collection}"
      end
      col = chat.database_collection?(collection)
      if col&.enabled == false
        raise OllamaChat::ToolFunctionArgumentError,
          "Collection #{collection} is disabled."
      end
      old_collection            = chat.documents.collection
      chat.documents.collection = collection
    end

    records = chat.find_document_records(query, tags:, text_size:, text_count:, min_similarity:)

    if rerank && records.any?
      pre_rerank  = records.size
      prompt_name = 'default'
      records = chat.rerank_records(query, records, prompt_name:)
      chat.log(:info, 'Tool: %d/%d passed rerank for %s' % [ records.size, pre_rerank, collection ],
          data: { collection:, prompt_name: })
    end

    chat.log(:info, "Snippets retrieved", data: {
      tool: name, collection: chat.documents.collection, hits: records.size
    })

    collection_name = chat.documents.collection
    message =
      if records.any?
        "Retrieved #{records.size} relevant snippets from collection #{collection_name.inspect} for query #{query.inspect}. See snippets below:\n\n" +
          records.map { |record|
            link = if record.source =~ %r(\Ahttps?://)
                     record.source
                   elsif record.source.present?
                     'file://%s' % File.expand_path(record.source)
                   end
            link && record.tags.any? or next
            [ link, ?# + record.tags.first ]
          }.flat_map { |l, t| chat.hyperlink(l, t) }.join(' ')
      else
        "No relevant snippets found for query #{query.inspect} in collection #{collection_name.inspect}."
      end

    {
      prompt: chat.prompt('snippets_retrieval').to_s,
      collection: {
        name:        collection_name,
        description: chat.database_collection?(collection_name)&.description&.to_s,
      },
      snippets: records.map do |record|
        {
          text:       record.text,
          similarity: record.similarity.to_f,
          tags:       record.tags_set.map { |t| { name: t.to_s(link: false), source: t.source }.compact }
        }
      end,
      message:,
      query:,
      tags:,
      min_similarity:,
      text_size:,
      text_count:,
      rerank:,
    }.to_json
  rescue => e
    chat.log(:error, e, data: { tool: name, query: args.query })
    { error: e.class.name, message: e.message }.to_json
  ensure
    old_collection and chat.documents.collection = old_collection
  end

  self
end.register
