# A tool for fetching content from URLs.
#
# This tool allows the chat client to retrieve content from a specified URL.
# It integrates with the Ollama tool calling system to provide web content
# fetching capabilities to the language model.
class OllamaChat::Tools::GetURL
  include OllamaChat::Tools::Concern

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
         Web fetcher – Downloads any web resource (HTML, Markdown, plain text)
         at url and makes its contents available to the model. Good for pulling
         documentation snippets.
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
  # @option opts [ComplexConfig::Settings] :config the configuration object
  # @return [String] the fetched content as a JSON string
  # @raise [StandardError] if there's an issue with the HTTP request or content fetching
  def execute(tool_call, **opts)
    config = opts[:config]
    args   = tool_call.function.arguments
    url    = args.url.to_s

    allowed_schemes = Array(config.tools.functions.get_url.schemes?).map(&:to_s)

    uri = URI.parse(args.url.to_s)
    unless allowed_schemes.include?(uri.scheme)
      raise ArgumentError, "scheme #{uri.scheme.inspect} not allowed "\
        "(allowed: #{allowed_schemes.join(', ')})"
    end

    OllamaChat::Utils::Fetcher.get(
      url,
      debug: OC::OLLAMA::CHAT::DEBUG,
      reraise: true,
    &:read)
  rescue => e
    { error: e.class, message: e.message, url: }.to_json
  end

  self
end.register
