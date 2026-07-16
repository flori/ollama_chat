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
class OllamaChat::Tools::RetrieveDocumentSnippets
  include OllamaChat::Tools::Concern
  include Kramdown::ANSI::Width

  # @return [String] the registered name for this tool
  def self.register_name = 'retrieve_document_snippets'

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
          Return document snippets from the current collection of documents
          that match the supplied query. The result is a JSON string containing
          a prompt header and an array of {text, tags} objects.
        EOT
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            query: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: <<~EOT,
                The query or text to search for in the document collection.
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
                The document collection to search in for the query or text.
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
  # @param opts [Hash] additional options, usually containing the chat
  # @return [String] JSON string with the resulting snippets, or an error
  # @raise [OllamaChat::OllamaChatError] if embeddings are disabled or query
  #   is empty
  def execute(tool_call, **opts)
    chat = opts[:chat]

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
      old_collection            = chat.documents.collection
      chat.documents.collection = collection
    end

    records = find_document_records(chat, query, tags, text_size, text_count, min_similarity)

    if rerank && records.any?
      records = rerank_records(chat, query, records)
    end

    collection_name = chat.documents.collection
    message =
      if records.any?
        "Retrieved #{records.size} relevant snippets from collection #{collection_name.inspect} for query #{query.inspect}. See snippets below:\n\n" +
          records.map { |record|
            link = if record.source =~ %r(\Ahttps?://)
                     record.source
                   else
                     'file://%s' % File.expand_path(record.source)
                   end
            link && record.tags.any? or next
            [ link, ?# + record.tags.first ]
          }.flat_map { |l, t| chat.hyperlink(l, t) }.join(' ')
      else
        "No relevant snippets found for query #{query.inspect} in collection #{collection_name.inspect}."
      end

    {
      prompt: 'Consider these snippets generated from retrieval when formulating your response!',
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
    chat.log(:error, e)
    { error: e.class.name, message: e.message }.to_json
  ensure
    old_collection and chat.documents.collection = old_collection
  end

  private

  # Uses the active chat model to filter records based on the query.
  #
  # @param chat [OllamaChat::Chat] the active  chat instance
  # @param query [String] the search query string
  # @param records [Array<Documentrix::Utils::TagResult>] the initial set of
  #   found records
  #
  # @return [Array<Documentrix::Utils::TagResult>] the filtered array of
  # records
  #
  # @raise [RuntimeError] if the 'rerank' prompt is missing from the
  #   configuration
  def rerank_records(chat, query, records)
    candidates = records.each_with_index.map { |r, i|
      "[#{i}] #{truncate(r.text.strip, length: 300)}"
    }.join("\n")

    prompt = chat.prompt('rerank') or raise "missing prompt 'rerank'"
    prompt = prompt.to_s % { query:, candidates: }

    begin
      # We use the active chat model to perform the surgical precision
      # filtering
      if response = chat.generate(prompt:).full?
        indices  = response.scan(/\d+/).map(&:to_i).select { |i| (0...records.size).include?(i) }
        records  = records.values_at(*indices) if indices.any?
      end
    rescue => e
      chat.log(:error, "Attempted reranking, caught #{e.class} #{e}")
    end
    records
  end

  # The find_document_records method searches for document records matching the
  # given query string.
  #
  # @param query [String] the search query string
  # @param min_similarity [Float, nil] the minimum similarity threshold
  #
  # @return [Array<Documentrix::Utils::TagResult>] an array of found document
  #   records
  def find_document_records(chat, query, tags, text_size, text_count, min_similarity)
    tags = Documentrix::Utils::Tags.new(tags, valid_tag: /\A#*([-\w.\]\[]+)/)

    chat.documents.find_where(
      query.first(chat.config.embedding.model.context_length),
      tags:,
      prompt:         chat.config.embedding.model.prompt?,
      text_size:      ,
      text_count:     ,
      min_similarity:
    )
  end

  self
end.register
