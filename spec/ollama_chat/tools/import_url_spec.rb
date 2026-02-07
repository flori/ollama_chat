require 'spec_helper'

describe OllamaChat::Tools::ImportURL do
  it 'can have name' do
    expect(described_class.new.name).to eq 'import_url'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  let(:chat) do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  connect_to_ollama_server

  let(:config) do
    chat.config
  end

  context "with a valid URL" do
    it "imports content from the URL" do
      tool_call = double(
        'ToolCall',
        function: double(
          name: 'import_url',
          arguments: double(
            url: 'https://www.example.com/foo'
          )
        )
      )

      expect(chat).to receive(:import).with('https://www.example.com/foo').
        and_return('bar')

      result = described_class.new.execute(tool_call, chat:)

      expect(result).to be_a(String)
      expect(result).to eq('bar')
    end
  end

  it "handles missing exceptions gracefully" do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'import_url',
        arguments: double(
          url: 'https://www.example.com/foo'
        )
      )
    )

    expect(chat).to receive(:import).with('https://www.example.com/foo').
      and_raise('it somehow failed')

    result = described_class.new.execute(tool_call, chat:)

    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to eq 'RuntimeError'
    expect(json.message).to eq 'it somehow failed'
  end
end
