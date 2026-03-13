# A tool for fetching RFC (Request for Comments) information.
#
# This tool allows the chat client to retrieve RFC details by ID from the
# RFC Editor website. It integrates with the Ollama tool calling system to
# provide technical documentation information to the language model.
class OllamaChat::Tools::GetRFC
  include OllamaChat::Tools::Concern

  # @return [String] the registered name for this tool
  def self.register_name = 'get_rfc'

  # Creates and returns a tool definition for getting RFC information.
  #
  # This method constructs the function signature that describes what the tool
  # does, its parameters, and required fields. The tool expects an RFC-ID
  # parameter to be provided.
  #
  # @return [Ollama::Tool] a tool definition for retrieving RFC information
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: <<~EOT,
         RFC fetcher – Downloads the full plain‑text of an Internet Standard
         (e.g., "rfc-2616"). No arguments beyond rfc_id.
        EOT
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            rfc_id: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The RFC-ID to get'
            ),
          },
          required: %w[rfc_id]
        )
      )
    )
  end

  # Executes the RFC lookup operation.
  #
  # This method fetches RFC data from the configured endpoint using the
  # provided RFC ID. It handles the HTTP request and returns the text content.
  #
  # @param tool_call [Ollama::Tool::Call] the tool call object containing function details
  # @param opts [Hash] additional options
  # @option opts [ComplexConfig::Settings] :config the configuration object
  # @return [String] the parsed RFC text or an error message as JSON string
  def execute(tool_call, **opts)
    config = opts[:config]
    rfc_id = tool_call.function.arguments.rfc_id
    url    = config.tools.functions.get_rfc.url % { rfc_id: }
    content = OllamaChat::Utils::Fetcher.get(
      url,
      headers: {
        'Accept' => 'text/plain',
      },
      debug: OC::OLLAMA::CHAT::DEBUG,
      reraise: true,
      &:read
    )
    {
      rfc_id: ,
      content:,
    }.to_json
  rescue => e
    { error: e.class, message: e.message }.to_json
  end

  self
end.register
