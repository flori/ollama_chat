describe OllamaChat::Tools::GetCurrentWeather do
  let :chat do
    OllamaChat::Chat.new argv: chat_default_config
  end

  connect_to_ollama_server

  let :tool do
    described_class.new
  end

  let :weather_data do
    asset_content('pirateweather.json')
  end

  it 'can have name' do
    expect(described_class.new.name).to eq 'get_current_weather'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end

  it 'can be executed for celsius' do
    expect(tool).to receive(:get_weather_data).and_return(weather_data)
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'get_current_weather',
        arguments: double()
      )
    )
    result = tool.execute(tool_call, config: chat.config)
    json = json_object(result)
    expect(json.current_time).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.\d{3}[+-]\d{2}:\d{2}\z/)
    expect(json.currently.temperature).to be_within(0.01).of(7.74)
    expect(json.units).to eq "si"
  end

  it 'can handle execution errors with structured JSON error response' do
    expect(tool).to receive(:get_weather_data).and_raise('Network error occurred')

    tool_call = double(
      'ToolCall',
      function: double(
        name: 'get_current_weather',
        arguments: double()
      )
    )

    result = tool.execute(tool_call, config: chat.config)

    # Parse the JSON result to verify structured error format
    json = json_object(result)

    # Verify the structured error response
    expect(json.error).to be_a String
    expect(json.message).to be_a String
    expect(json.error).to eq 'RuntimeError'
    expect(json.message).to include('Network error occurred')
  end
end
