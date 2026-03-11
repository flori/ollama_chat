describe OllamaChat::Tools::CopyToClipboard do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  let :config do
    chat.config
  end

  connect_to_ollama_server

  it 'can have name' do
    expect(described_class.new.name).to eq 'copy_to_clipboard'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end

  it 'can be executed successfully without provided text' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'copy_to_clipboard',
        arguments: double(
          text: nil
        )
      )
    )

    # Test that perform_copy_to_clipboard is called with content: true
    expect(chat).to receive(:perform_copy_to_clipboard).with(text: nil, content: true)

    result = described_class.new.execute(tool_call, chat: chat)

    # Should return valid JSON
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to be_nil # No exception was raised
    expect(json.success).to be true
    expect(json.message).to eq 'The last response has been successfully copied to the system clipboard.'
  end

  it 'can copy custom text to the clipboard' do
    text = "This is a custom text to copy"

    tool_call = double(
      'ToolCall',
      function: double(
        name: 'copy_to_clipboard',
        arguments: double(
          text:
        )
      )
    )

    # Test that perform_copy_to_clipboard is called with the custom text
    expect(chat).to receive(:perform_copy_to_clipboard).with(text:, content: true)

    result = described_class.new.execute(tool_call, chat: chat)

    # Should return valid JSON
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to be_nil # No exception was raised
    expect(json.success).to be true
    expect(json.message).to eq 'The provided text has been successfully copied to the system clipboard.'
  end

  it 'can handle execution errors gracefully' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'copy_to_clipboard',
        arguments: double(
          text: nil
        )
      )
    )

    # Test that perform_copy_to_clipboard raises an error
    expect(chat).to receive(:perform_copy_to_clipboard).with(text:nil, content: true).
      and_raise(OllamaChat::OllamaChatError, 'No response available to copy to the system clipboard.')

    result = described_class.new.execute(tool_call, chat: chat)

    # Should return valid JSON even with errors
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to eq 'OllamaChat::OllamaChatError'
    expect(json.message).to eq 'No response available to copy to the system clipboard.'
  end

  it 'can handle execution exceptions gracefully' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'copy_to_clipboard',
        arguments: double(
          text: nil
        )
      )
    )

    # Test that perform_copy_to_clipboard raises an exception
    expect(chat).to receive(:perform_copy_to_clipboard).with(text: nil, content: true).
      and_raise(RuntimeError, 'some kind of exception')

    result = described_class.new.execute(tool_call, chat: chat)

    # Should return valid JSON even with exceptions
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to eq 'RuntimeError'
    expect(json.message).to eq 'some kind of exception'
  end
end
