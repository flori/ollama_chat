# Provides functionality to retrieve current weather data from a configured
# weather service. The class registers itself as a tool and implements
# execution logic for obtaining weather information. It uses the
# GetCurrentWeather tool to fetch data via the configured weather endpoint.
class OllamaChat::Tools::GetCurrentWeather
  include OllamaChat::Tools::Concern

  # Register the tool name for the Ollama tool‑calling system.
  #
  # @return [String] the registered tool name 'get_current_weather'
  def self.register_name = 'get_current_weather'

  # The tool method creates and returns a tool definition for getting
  # current weather information.
  #
  # This method constructs a tool specification that can be used to invoke
  # a weather information service. The tool definition includes the
  # function name and description.
  #
  # @return [Ollama::Tool] a tool definition for retrieving current weather
  #   information
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: 'Get the current weather for the configured location',
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {},
          required: []
        )
      )
    )
  end

  # Executes a tool call to get current weather information for the configured
  # location.
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
    config = opts[:config]
    units  = config.location.units =~ /SI/ ? 'si' : 'us'
    data   = { current_time: Time.now, units: } |
      JSON(get_weather_data(config, units)).deep_symbolize_keys
    data.to_json
  rescue => e
    {
      error:   e.class,
      message: "Failed to fetch weather data: #{e.message}"
    }.to_json
  end

  private

  # Retrieves current weather data from the Pirate Weather API using the
  # provided configuration and units.
  #
  # It constructs an API request URL based on the location coordinates and unit
  # system, includes api key as header. The method returns the parsed JSON
  # response containing weather information.
  #
  # @param config [ComplexConfig::Config] the configuration object containing
  #   location and tool settings
  #
  # @param units [String] the unit system for temperature (e.g., metric or
  #   imperial)
  #
  # @return [Hash] the parsed weather data
  #
  # @raise [OllamaChat::ConfigMissingError] if the required Pirate Weather API
  #   key is missing
  def get_weather_data(config, units)
    api_key    = OC::OLLAMA::CHAT::TOOLS::PIRATEWEATHER_API_KEY? or
      raise OllamaChat::ConfigMissingError, 'require env var OLLAMA_CHAT_TOOLS_PIRATEWEATHER_API_KEY'
    lat, lon = config.location.decimal_degrees
    url      = config.tools.functions.get_current_weather.url % {
      lat:, lon:, units:, api_key:,
    }
    headers = {
      'Accept'         => 'application/json',
      'User-Agent'     => OllamaChat::Chat.user_agent,
      'apikey'         => api_key,
    }
    OllamaChat::Utils::Fetcher.get(
      url,
      headers:,
      debug: OC::OLLAMA::CHAT::DEBUG,
      reraise: true,
      &valid_json?
    )
  end

  self
end.register
