# A tool for searching the web using configured search engines.
#
# This tool enables the chat client to perform web searches using either
# DuckDuckGo or SearxNG search engines, depending on the configuration. It
# integrates with the Ollama tool calling system to provide web search
# capabilities to language models.
class OllamaChat::Tools::SearchWeb
  include OllamaChat::Tools::Concern

  def self.register_name = 'search_web'

  # Creates and returns a tool definition for web search functionality
  #
  # This method constructs the function signature that describes what the tool
  # does, its parameters, and required fields. The tool expects a search query
  # parameter and optional parameters for result count.
  #
  # @return [Ollama::Tool] a tool definition for performing web searches
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: 'Search the web for information using a search query',
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            query: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The search query to use for web search'
            ),
            num_results: Tool::Function::Parameters::Property.new(
              type: 'integer',
              description: 'Number of results to return (default: 5)'
            )
          },
          required: %w[query]
        )
      )
    )
  end

  # Executes the web search operation
  #
  # This method performs a web search using the existing
  # OllamaChat::WebSearching module functionality. It leverages the configured
  # search engine and returns structured search results.
  #
  # @param tool_call [Ollama::Tool::Call] the tool call object containing function details
  # @param opts [Hash] additional options
  # @option opts [ComplexConfig::Settings] :config the configuration object
  # @option opts [OllamaChat::Chat] :chat the chat instance for location context
  # @return [String] the search results as a JSON string
  # @raise [StandardError] if there's an issue with the search operation
  def execute(tool_call, **opts)
    chat   = opts[:chat]
    config = opts[:config]
    args = tool_call.function.arguments

    query = args.query
    max_results = config.tools.search_web?.max_results? || 10
    num_results = (args.num_results || 5).clamp(..max_results)
    {
      query: ,
      url:   chat.search_web(query, num_results)
    }.to_json
  rescue => e
    {
      error: e.class,
      message: e.message,
    }.to_json
  end

  self
end.register
