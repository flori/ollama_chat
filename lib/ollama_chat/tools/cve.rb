# A tool for fetching CVE (Common Vulnerabilities and Exposures) information.
#
# This tool allows the chat client to retrieve CVE details by ID from a configured
# API endpoint. It integrates with the Ollama tool calling system to provide
# security-related information to the language model.
#
# @example Using the CVE tool
#   # The tool can be invoked with a CVE ID
#   { "name": "get_cve", "arguments": { "cve_id": "CVE-2023-12345" } }
#
# @see OllamaChat::Tools
class OllamaChat::Tools::CVE
  include Ollama

  # Initializes a new CVE tool instance.
  #
  # @return [OllamaChat::Tools::CVE] a new CVE tool instance
  def initialize
    @name = 'get_cve'
  end

  # Returns the name of the tool.
  #
  # @return [String] the name of the tool ('get_cve')
  attr_reader :name

  # Creates and returns a tool definition for getting CVE information.
  #
  # This method constructs the function signature that describes what the tool
  # does, its parameters, and required fields. The tool expects a CVE-ID
  # parameter to be provided.
  #
  # @return [Ollama::Tool] a tool definition for retrieving CVE information
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: 'Get the CVE for id as JSON',
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            cve_id: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The CVE-ID to get'
            ),
          },
          required: %w[cve_id]
        )
      )
    )
  end

  # Executes the CVE lookup operation.
  #
  # This method fetches CVE data from the configured API endpoint using the
  # provided CVE ID. It handles the HTTP request, parses the JSON response,
  # and returns the structured data.
  #
  # @param tool_call [Ollama::Tool::Call] the tool call object containing function details
  # @param opts [Hash] additional options
  # @option opts [ComplexConfig::Settings] :config the configuration object
  # @return [Hash, String] the parsed CVE data as a hash or an error message
  # @raise [StandardError] if there's an issue with the HTTP request or JSON parsing
  def execute(tool_call, **opts)
    config = opts[:config]
    cve_id = tool_call.function.arguments.cve_id
    url    = config.tools.get_cve.url % { cve_id: }
    OllamaChat::Utils::Fetcher.get(
      url,
      headers: {
        'Accept' => 'application/json',
      },
      debug: OllamaChat::EnvConfig::OLLAMA::CHAT::DEBUG
    ) do |tmp|
      data = JSON.parse(tmp.read, object_class: JSON::GenericObject)
      return data
    end
  rescue StandardError => e
    { error: e.class, message: e.message }.to_json
  end

  # Converts the tool to a hash representation.
  #
  # This method provides a standardized way to serialize the tool definition
  # for use in tool calling systems.
  #
  # @return [Hash] a hash representation of the tool
  def to_hash
    tool.to_hash
  end
end
