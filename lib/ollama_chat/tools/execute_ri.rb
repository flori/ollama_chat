# A tool for looking up Ruby ri documentation.
#
# This tool allows the chat client to query Ruby's built‑in `ri` command
# which provides quick access to standard library and gem documentation.
# It follows the same interface conventions as other tools in this
# repository, making it easy to integrate with the Ollama API.
class OllamaChat::Tools::ExecuteRI
  include OllamaChat::Tools::Concern

  # Register tool name for Ollama's function calling system
  def self.register_name = 'execute_ri'

  # Returns a Tool definition that describes this functionality to
  # the LLM.
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: 'Look up Ruby documentation for classes, modules and methods using the `ri` command.',
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            topic: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The Ruby class/module/method to query. For example `Array`, or `String#split`.'
            ),
          },
          required: ['topic']
        )
      )
    )
  end

  # Execute the ri command based on parsed tool call.
  def execute(tool_call, **opts)
    args   = tool_call.function.arguments
    topic  = args.topic.full? or raise ArgumentError, 'require a topic of ri'
    cmd    = [ 'ri', topic ]
    result = OllamaChat::Utils::Fetcher.execute(cmd, &:read)
    { cmd:, result: }.to_json
  rescue => e
    { error: e.class, message: e.message }.to_json
  end

  self
end.register
