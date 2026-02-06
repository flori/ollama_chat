# A tool for fetching endoflife.date product information.
#
# This tool allows the chat client to retrieve endoflife.date information
# for software products by ID. It integrates with the Ollama tool calling
# system to provide lifecycle and support information to the language model.
class OllamaChat::Tools::EndOfLife
  include OllamaChat::Tools::Concern

  def self.register_name = 'get_endoflife'

  # Creates and returns a tool definition for getting endoflife information.
  #
  # This method constructs the function signature that describes what the tool
  # does, its parameters, and required fields. The tool expects a product name
  # parameter to be provided.
  #
  # @return [Ollama::Tool] a tool definition for retrieving endoflife information
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: 'Get the endoflife information for a product as JSON',
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            product: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The product name to get endoflife information for'
            ),
          },
          required: %w[product]
        )
      )
    )
  end

  # Executes the endoflife lookup operation.
  #
  # This method fetches endoflife data from the endoflife.date API using the
  # provided product name. It handles the HTTP request, parses the JSON response,
  # and returns the structured data.
  #
  # @param tool_call [Ollama::Tool::Call] the tool call object containing function details
  # @param opts [Hash] additional options
  # @option opts [ComplexConfig::Settings] :config the configuration object
  # @return [Hash, String] the parsed endoflife data as a hash or an error message
  # @raise [StandardError] if there's an issue with the HTTP request or JSON parsing
  def execute(tool_call, **opts)
    config = opts[:config]
    product = tool_call.function.arguments.product

    # Construct the URL for the endoflife API
    url = config.tools.get_endoflife.url % { product: }

    # Fetch the data from endoflife.date API
    OllamaChat::Utils::Fetcher.get(
      url,
      headers: {
        'Accept' => 'application/json',
        'User-Agent' => OllamaChat::Chat.user_agent
      },
      debug: OllamaChat::EnvConfig::OLLAMA::CHAT::DEBUG
    ) do |tmp|
      # Parse the JSON response
      data = JSON.parse(tmp.read, object_class: JSON::GenericObject)
      return data
    end
  rescue => e
    "Failed to fetch endoflife data for #{product}: #{e.class}: #{e.message}"
  end

  self
end.register
