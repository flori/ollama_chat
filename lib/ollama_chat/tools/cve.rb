# A tool for fetching CVE (Common Vulnerabilities and Exposures) information.
#
# This tool allows the chat client to retrieve CVE details by ID from a configured
# API endpoint. It integrates with the Ollama tool calling system to provide
# security-related information to the language model.
class OllamaChat::Tools::CVE
  include OllamaChat::Tools::Concern

  def self.register_name = 'get_cve'

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
  # @return [String] the parsed CVE data or an error message as JSON string
  def execute(tool_call, **opts)
    config = opts[:config]
    cve_id = tool_call.function.arguments.cve_id
    url    = config.tools.get_cve.url % { cve_id: }
    OllamaChat::Utils::Fetcher.get(
      url,
      headers: {
        'Accept' => 'application/json',
      },
      debug: OllamaChat::EnvConfig::OLLAMA::CHAT::DEBUG,
      &valid_json?
    )
  rescue => e
    { error: e.class, message: e.message }.to_json
  end

  self
end.register
