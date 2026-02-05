require_relative 'weather/dwd_sensor'

# A module that provides tool registration and management for OllamaChat.
#
# The Tools module serves as a registry for available tools that can be
# invoked during chat conversations. It maintains a collection of
# registered tools and provides methods for registering new tools and
# accessing the complete set of available tools for use in chat
# interactions.
class OllamaChat::Tools::Weather
  include Ollama

  # The initialize method sets up the weather tool with its name.
  def initialize
    @name = 'get_current_weather'
  end

  # The name reader returns the name of the tool.
  #
  # @return [ String ] the name of the tool
  attr_reader :name

  # The tool method creates and returns a tool definition for getting
  # current weather information.
  #
  # This method constructs a tool specification that can be used to invoke
  # a weather information service. The tool definition includes the
  # function name, description, and parameter specifications for location
  # and temperature unit.
  #
  # @return [Ollama::Tool] a tool definition for retrieving current weather
  #   information
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: 'Get the current weather for a location',
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            location: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The location to get the weather for, e.g. San Francisco, CA'
            ),
            temperature_unit: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: "The unit to return the temperature in, either 'celsius' or 'fahrenheit'",
              enum: %w[celsius fahrenheit]
            )
          },
          required: %w[location temperature_unit]
        )
      )
    )
  end

  # Executes a tool call to get current weather information.
  #
  # This method retrieves temperature data from a weather sensor using the
  # DWD (German Weather Service) API and formats the result into a
  # human-readable string including the temperature value, unit, and
  # timestamp.
  #
  # @param tool_call [Object] the tool call object containing function
  #   details
  # @param opts [Hash] additional options
  # @option opts [ComplexConfig::Settings] :config the configuration object
  #
  # @return [String] a formatted weather report or error message
  # @return [String] an error message if the weather data could not be
  #   retrieved
  def execute(tool_call, **opts)
    station_id = opts[:config].tools.get_current_weather.station_id
    sensor = DWDSensor.new(
      sensor_id:   "dwd_#{station_id}",
      station_id:  ,
      logger:      Logger.new(STDOUT)
    )

    time, temp = sensor.measure

    unless time && temp
      return "Could not retrieve temperature for station #{station_id}"
    end

    unit = ?℃

    if tool_call.function.arguments.temperature_unit == 'fahrenheit'
      unit = ?℉
      temp = temp * 9.0 / 5 + 32
    end

    "The temperature was %s %s at the time of %s" % [ temp, unit, time ]
  rescue StandardError => e
    "Failed to fetch weather for station #{station_id} #{e.class}: #{e.message}"
  end

  # The to_hash method converts the tool to a hash representation.
  #
  # @return [ Hash ] a hash representation of the tool
  def to_hash
    tool.to_hash
  end
end
