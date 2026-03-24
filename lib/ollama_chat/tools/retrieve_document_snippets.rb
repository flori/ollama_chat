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
              description: 'The query or text to search for in the document collection.'
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

    query = tool_call.function.arguments.query.to_s

    query.blank? and raise OllamaChat::OllamaChatError, 'Empty query'


    records = find_document_records(chat, query)

    message = records.map { |record|
      link = if record.source =~ %r(\Ahttps?://)
               record.source
             else
               'file://%s' % File.expand_path(record.source)
             end
      [ link, ?# + record.tags.first ]
    }.uniq.map { |l, t| chat.hyperlink(l, t) }.join(' ')

    {
      prompt: 'Consider these snippets generated from retrieval when formulating your response!',
      ollama_chat_retrieval_snippets: records.map do |record|
        {
          text: record.text,
          tags: record.tags_set.map { |t| { name: t.to_s(link: false), source: t.source }.compact }
        }
      end,
      message:,
    }.to_json
  rescue => e
    { error: e.class.name, message: e.message }.to_json
  end

  private

  # The find_document_records method searches for document records matching the
  # given query string.
  #
  # @param query [String] the search query string
  #
  # @return [Array<Documentrix::Utils::TagResult>] an array of found document
  #   records
  def find_document_records(chat, query)
    tags = Documentrix::Utils::Tags.new(valid_tag: /\A#*([\w\]\[]+)/)

    chat.documents.find_where(
      query.downcase.first(chat.config.embedding.model.context_length),
      tags:,
      prompt: chat.config.embedding.model.prompt?,
      text_size: chat.config.embedding.found_texts_size?,
      text_count: chat.config.embedding.found_texts_count?
    )
  end

  self
end.register
