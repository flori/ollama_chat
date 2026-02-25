require 'spec_helper'

describe OllamaChat::Tools::PasteFromClipboard do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  let :config do
    chat.config
  end

  connect_to_ollama_server

  it 'can have name' do
    expect(described_class.new.name).to eq 'paste_from_clipboard'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end

  it 'can be executed successfully' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'paste_from_clipboard',
        arguments: double()
      )
    )

    # Test that perform_paste_from_clipboard is called
    expect(chat).to receive(:perform_paste_from_clipboard)

    result = described_class.new.execute(tool_call, chat: chat)

    # Should return valid JSON
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to be_nil # No exception was raised
    expect(json.success).to be true
    expect(json.message).to eq 'Content pasted from clipboard'
  end

  it 'can handle execution errors gracefully' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'paste_from_clipboard',
        arguments: double()
      )
    )

    # Test that perform_paste_from_clipboard raises an error
    expect(chat).to receive(:perform_paste_from_clipboard).
      and_raise(OllamaChat::OllamaChatError, 'No content available to paste from the system clipboard.')

    result = described_class.new.execute(tool_call, chat: chat)

    # Should return valid JSON even with errors
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to eq 'OllamaChat::OllamaChatError'
    expect(json.message).to eq 'No content available to paste from the system clipboard.'
  end

  it 'can handle execution exceptions gracefully' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'paste_from_clipboard',
        arguments: double()
      )
    )

    # Test that perform_paste_from_clipboard raises an exception
    expect(chat).to receive(:perform_paste_from_clipboard).
      and_raise(RuntimeError, 'some kind of exception')

    result = described_class.new.execute(tool_call, chat: chat)

    # Should return valid JSON even with exceptions
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to eq 'RuntimeError'
    expect(json.message).to eq 'some kind of exception'
  end
end
