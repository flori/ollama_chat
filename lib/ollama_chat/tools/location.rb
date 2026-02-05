# A tool for retrieving the current location, time, and system of units.
#
# This tool allows the chat client to get the current location information,
# including time and system of units for the user. It integrates with the
# Ollama tool calling system to provide contextual location data to the language model.
#
# The tool returns structured JSON data containing location coordinates, time,
# and unit system information.
class OllamaChat::Tools::Location
  include Ollama

  # Initializes a new get_location tool instance.
  #
  # @return [OllamaChat::Tools::Location] a new get_location tool instance
  def initialize
    @name = 'get_location'
  end

  # Returns the name of the tool.
  #
  # @return [String] the name of the tool ('get_location')
  attr_reader :name

  # Creates and returns a tool definition for getting location information.
  #
  # This method constructs the function signature that describes what the tool
  # does, its parameters, and required fields. The tool takes no parameters.
  #
  # @return [Ollama::Tool] a tool definition for retrieving location information
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

  # Executes the location retrieval operation.
  #
  # This method fetches the current location data from the chat instance
  # and returns it as JSON.
  #
  # @param tool_call [Ollama::Tool::Call] the tool call object containing function details
  # @param opts [Hash] additional options
  # @option opts [OllamaChat::Chat] :chat the chat instance containing location data
  # @return [String] the location data as a JSON string
  # @raise [StandardError] if there's an issue with location data retrieval or JSON serialization
  def execute(tool_call, **opts)
    chat = opts[:chat]
    chat.location_data.to_json
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
