require 'spec_helper'

describe OllamaChat::Tools::GetLocation do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  connect_to_ollama_server

  it 'can have name' do
    expect(described_class.new.name).to eq 'get_location'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end

  it 'can be executed successfully' do
    # Mock the chat instance with location_data
    location_data = {
      latitude: 40.7128,
      longitude: -74.0060,
      units: 'metric'
    }

    expect(chat).to receive(:location_data).and_return location_data

    tool_call = double(
      'ToolCall',
      function: double(
        name: 'get_location',
        arguments: double()
      )
    )

    result = described_class.new.execute(tool_call, chat:)

    json = json_object(result)
    expect(json.latitude).to be_within(0.0001).of(40.7128)
    expect(json.longitude).to be_within(0.0001).of(-74.0060)
    expect(json.units).to eq 'metric'
  end

  it 'can handle execution errors gracefully' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'get_location',
        arguments: double()
      )
    )

    # Test that the method handles nil location_data gracefully
    expect {
      described_class.new.execute(tool_call, chat:)
    }.to_not raise_error
  end

  context 'when location_data is not available' do
    it 'returns valid JSON even with missing data' do
      tool_call = double(
        'ToolCall',
        function: double(
          name: 'get_location',
          arguments: double()
        )
      )

      result = described_class.new.execute(tool_call, chat:)
      # Should still be valid JSON even if location_data is nil
      expect { JSON.parse(result) }.to_not raise_error
    end
  end
end
