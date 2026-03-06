require 'spec_helper'

describe OllamaChat::Tools::ExecuteRI do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  connect_to_ollama_server

  it 'can have name' do
    expect(described_class.new.name).to eq 'execute_ri'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end

  context 'when executed successfully with a valid topic' do
    let(:topic) { 'Tins::Full#full?' }

    before do
      allow(OllamaChat::Utils::Fetcher).to receive(:execute)
        .with(["ri", topic])
        .and_return('Documentation text for Tins::Full#full?')
    end

    it 'returns JSON containing cmd and result' do
      tool_call = double(
        'ToolCall',
        function: double(
          name: 'execute_ri',
          arguments: double(topic: topic)
        )
      )

      result = described_class.new.execute(tool_call, config: chat.config)

      expect(result).to be_a String
      json = json_object(result)
      expect(json.cmd).to include('ri')
      expect(json.cmd).to include(topic)
      expect(json.result).to eq 'Documentation text for Tins::Full#full?'
    end
  end

  context 'when topic is missing or invalid' do
    it 'returns an error JSON due to ArgumentError on full?' do
      tool_call = double(
        'ToolCall',
        function: double(
          name: 'execute_ri',
          arguments: double(topic: nil)
        )
      )

      result = described_class.new.execute(tool_call, config: chat.config)

      json = json_object(result)
      expect(json.error).to eq('ArgumentError')
    end
  end

  context 'when fetcher raises an exception' do
    before do
      allow(OllamaChat::Utils::Fetcher).to receive(:execute)
        .and_raise('my error')
    end

    it 'returns a JSON with the error class and message' do
      tool_call = double(
        'ToolCall',
        function: double(
          name: 'execute_ri',
          arguments: double(topic: 'Array#each')
        )
      )

      result = described_class.new.execute(tool_call, config: chat.config)

      json = json_object(result)
      expect(json.error).to eq('RuntimeError')
      expect(json.message).to include('my error')
    end
  end
end
