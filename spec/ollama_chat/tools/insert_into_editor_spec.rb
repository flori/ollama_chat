require 'spec_helper'

describe OllamaChat::Tools::InsertIntoEditor do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  let :config do
    chat.config
  end

  connect_to_ollama_server

  it 'has the correct name' do
    expect(described_class.new.name).to eq('insert_into_editor')
  end

  it 'provides a Tool instance for the LLM' do
    expect(described_class.new.tool).to be_a(Ollama::Tool)
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a(Hash)
  end

  context 'execution without explicit text (uses last response)' do
    let(:tool_call) do
      double(
        'ToolCall',
        function: double(
          name:   'insert_into_editor',
          arguments: double(text: nil)
        )
      )
    end

    it 'calls perform_insert with nil and returns a success JSON' do
      expect(chat).to receive(:perform_insert)
        .with(text: nil, content: true).and_return true

      result = described_class.new.execute(tool_call, chat:, config:)
      json   = json_object(result)

      expect(json.error).to be_nil
      expect(json.success).to eq(true)
      expect(json.message).to eq(
        'The last response has been successfully inserted into the editor.'
      )
    end

    it 'returns a success JSON even if no message is available' do
      allow(chat).to receive(:perform_insert).and_return(true)

      result = described_class.new.execute(tool_call, chat:, config:)
      json   = json_object(result)
      expect(json.success).to be true
    end
  end

  context 'execution with explicit custom text' do
    let(:custom_text) { "Hello World!" }
    let(:tool_call) do
      double(
        'ToolCall',
        function: double(
          name:   'insert_into_editor',
          arguments: double(text: custom_text)
        )
      )
    end

    it 'calls perform_insert with the supplied text' do
      expect(chat).to receive(:perform_insert)
            .with(text: custom_text, content: true)

      result = described_class.new.execute(tool_call, chat:, config:)
      json   = json_object(result)

      expect(json.error).to be_nil
      expect(json.success).to eq(true)
      expect(json.message).to eq(
        'The provided text has been successfully inserted into the editor.'
      )
    end
  end

  context 'execution error handling' do
    let(:tool_call) do
      double(
        'ToolCall',
        function: double(
          name: :insert_into_editor,
          arguments: double(text: nil)
        )
      )
    end

    it 'captures OllamaChat::OllamaChatError and returns JSON with the error details' do
      expect(chat).to receive(:perform_insert)
            .and_raise(OllamaChat::OllamaChatError, 'Insert failed')

      result = described_class.new.execute(tool_call, chat:, config:)
      json   = json_object(result)

      expect(json.error).to eq('OllamaChat::OllamaChatError')
      expect(json.message).to eq('Insert failed')
    end

    it 'captures generic RuntimeError and returns JSON with the error details' do
      expect(chat).to receive(:perform_insert)
            .and_raise(RuntimeError, 'Some exception')

      result = described_class.new.execute(tool_call, chat:, config:)
      json   = json_object(result)

      expect(json.error).to eq('RuntimeError')
      expect(json.message).to eq('Some exception')
    end
  end

  context 'when configuration requires confirmation (insert_into_editor)' do
    it 'is registered and respects the configuration' do
      expect(OllamaChat::Tools.registered?('insert_into_editor')).to be true
    end
  end
end
