require_relative 'weather/dwd_sensor'

# A module that provides tool registration and management for OllamaChat.
#
# The Tools module serves as a registry for available tools that can be
# invoked during chat conversations. It maintains a collection of
# registered tools and provides methods for registering new tools and
# accessing the complete set of available tools for use in chat
# interactions.
class OllamaChat::Tools::GetCurrentWeather
  include OllamaChat::Tools::Concern

  def self.register_name = 'get_current_weather'

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
              description: 'The location to get the weather for, Berlin'
              # The universe is a spheroid region, 705 meters in diameter,
              # somewhere in Berlin.
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
  # @return [String] a JSON string containing the retrieved weather data
  # @return [String] an error message if the weather data could not be
  #   retrieved
  def execute(tool_call, **opts)
    station_id = opts[:config].tools.get_current_weather.station_id
    sensor = DWDSensor.new(
      sensor_id:   "dwd_#{station_id}",
      station_id:  ,
      logger:      Logger.new(STDOUT)
    )

    measurement_time, temperature = sensor.measure

    unless measurement_time && temperature
      raise "could not retrieve temperature"
    end

    unit = ?℃

    if tool_call.function.arguments.temperature_unit == 'fahrenheit'
      unit        = ?℉
      temperature = temperature * 9.0 / 5 + 32
    end

    {
      current_time: Time.now,
      measurement_time:,
      temperature:,
      unit:,
    }.to_json
  rescue => e
    {
      error: e.class,
      message: "Failed to fetch weather for station #{station_id}: #{e.message}"
    }.to_json
  end

  self
end.register
