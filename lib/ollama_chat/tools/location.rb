class OllamaChat::Tools::Location
  include Ollama

  def initialize
    @name = 'get_location'
  end

  attr_reader :name

  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: 'Get the current location, time and system of units of the user as JSON',
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {},
          required: []
        )
      )
    )
  end

  def execute(tool_call, **opts)
    chat = opts[:chat]
    chat.location_data.to_json
  end

  def to_hash
    tool.to_hash
  end
end
