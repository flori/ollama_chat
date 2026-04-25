# A tool for fetching content from URLs.
#
# This tool allows the chat client to retrieve content from a specified URL.
# It integrates with the Ollama tool calling system to provide web content
# fetching capabilities to the language model.
class OllamaChat::Tools::GetURL
  include OllamaChat::Tools::Concern

  # @return [String] the registered name for this tool
  def self.register_name = 'get_url'

  # Creates and returns a tool definition for fetching content from URLs.
  #
  # This method constructs the function signature that describes what the tool
  # does, its parameters, and required fields. The tool expects a URL
  # parameter.
  #
  # @return [Ollama::Tool] a tool definition for retrieving content from URLs
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: <<~EOT,
         Web fetcher – Downloads any web resource (HTML, Markdown, plain text, or images)
         at url and makes its contents available to the model. Good for pulling
         documentation snippets or viewing generated images.
        EOT
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            url: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: <<~EOT,
                The URL to get content from. This can be any valid HTTP or
                HTTPS URL pointing to a web resource that can be retrieved and
                processed by the chat system. The tool handles the HTTP request
                and returns the content.
              EOT
            ),
            document_policy: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: <<~EOT,
                The policy for handling the fetched text content, it defaults
                to 'ignoring'. Note that policies other than 'ignoring'
                typically transform the source content into a text-based
                representation
                (e.g., HTML to Markdown, PDF to text) before processing.
                - 'ignoring': Returns the raw content without any transformation (best for raw text, logs, or code).
                - 'importing': Processes content (e.g., HTML to Markdown) and adds it to the chat context.
                - 'embedding': Processes the content for vector storage.
                - 'summarizing': Returns a condensed summary of the content.
              EOT
            ),
          },
          required: %w[url]
        )
      )
    )
  end

  # Executes the URL fetching operation.
  #
  # This method fetches content from the specified URL using the configured
  # fetcher. It handles the HTTP request and returns the content.
  #
  # @param tool_call [Ollama::Tool::Call] the tool call object containing function details
  # @param opts [Hash] additional options
  # @option opts [ComplexConfig::Settings] :chat the chat instance
  # @return [String] the fetched content as a JSON string
  # @raise [StandardError] if there's an issue with the HTTP request or content fetching
  def execute(tool_call, **opts)
    chat            = opts[:chat]
    config          = chat.config
    args            = tool_call.function.arguments
    url             = args.url.to_s
    document_policy = args.document_policy.full? || 'ignoring'

    allowed_schemes = Array(config.tools.functions.get_url.schemes?).map(&:to_s)

    url = URI.parse(args.url.to_s)
    unless allowed_schemes.include?(url.scheme)
      raise OllamaChat::ToolFunctionArgumentError,
        "scheme #{url.scheme.inspect} not allowed "\
        "(allowed: #{allowed_schemes.join(', ')})"
    end

    source, message, content = url, nil, ''
    chat.fetch_source(source, check_exist: false) do |source_io|
      case source_io&.content_type&.media_type
      when 'image'
        chat.add_image(chat.images, source_io, source)
      when 'text', 'application', nil
        case document_policy
        when 'ignoring'
          content = source_io.read
        when 'importing'
          content = chat.import_source(source_io, source)
        when 'embedding'
          content = chat.embed_source(source_io, source)
        when 'summarizing'
          content = chat.summarize_source(source_io, source)
        else
          message = "Invalid document policy #{document_policy.inspect} used."
        end
      else
        message = "Cannot fetch #{source.to_s.inspect} with content type "\
          "#{source_io&.content_type.inspect}"
      end
    end
    message ||= "Received requested URL successfully."

    {
      url:,
      content:,
      message:,
    }.to_json
  rescue => e
    { error: e.class, message: e.message, url: }.to_json
  end

  self
end.register
