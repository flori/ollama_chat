require 'spec_helper'

describe OllamaChat::Tools::Weather do
  let :chat do
    OllamaChat::Chat.new argv: chat_default_config
  end

  connect_to_ollama_server

  it 'can have name' do
    expect(described_class.new.name).to eq 'get_current_weather'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  it 'can be executed for celsius' do
    expect(DWDSensor).to receive(:new).and_return(
      double(measure: [ Time.now, 23.0 ])
    )
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'get_current_weather',
        arguments: double(
          location:          'Berlin',
          temperature_unit:  'celsius'
        )
      )
    )
    expect(
      described_class.new.execute(tool_call, config: chat.config)
    ).to match(/The temperature was 23.0 ℃ at the time of /)
  end

  it 'can be executed for fahrenheit' do
    expect(DWDSensor).to receive(:new).and_return(
      double(measure: [ Time.now, 23.0 ])
    )
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'get_current_weather',
        arguments: double(
          location:          'Berlin',
          temperature_unit:  'fahrenheit'
        )
      )
    )
    expect(
      described_class.new.execute(tool_call, config: chat.config)
    ).to match(/The temperature was 73.4 ℉ at the time of /)
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end
end
