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
      time: '2023-05-15T14:30:00Z',
      units: 'metric'
    }

    chat_instance = double('Chat', location_data: location_data)

    tool_call = double(
      'ToolCall',
      function: double(
        name: 'get_location',
        arguments: double()
      )
    )

    result = described_class.new.execute(tool_call, chat: chat_instance)

    # Parse the JSON result to verify content
    parsed_result = JSON.parse(result)
    expect(parsed_result['latitude']).to be_within(0.0001).of(40.7128)
    expect(parsed_result['longitude']).to be_within(0.0001).of(-74.0060)
    expect(parsed_result['time']).to eq '2023-05-15T14:30:00Z'
    expect(parsed_result['units']).to eq 'metric'
  end

  it 'can handle execution errors gracefully' do
    # Mock a chat instance that raises an error when accessing location_data
    chat_instance = double('Chat', location_data: nil)

    tool_call = double(
      'ToolCall',
      function: double(
        name: 'get_location',
        arguments: double()
      )
    )

    # Test that the method handles nil location_data gracefully
    expect {
      described_class.new.execute(tool_call, chat: chat_instance)
    }.to_not raise_error
  end

  context 'when location_data is not available' do
    it 'returns valid JSON even with missing data' do
      chat_instance = double('Chat', location_data: nil)

      tool_call = double(
        'ToolCall',
        function: double(
          name: 'get_location',
          arguments: double()
        )
      )

      result = described_class.new.execute(tool_call, chat: chat_instance)
      # Should still be valid JSON even if location_data is nil
      expect { JSON.parse(result) }.to_not raise_error
    end
  end
end
