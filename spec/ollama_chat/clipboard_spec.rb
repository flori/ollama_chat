describe OllamaChat::Clipboard do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config).expose
  end

  connect_to_ollama_server

  it 'can copy last response to clipboard' do
    expect(chat).to receive(:feedback).with(a_string_including('No text available to copy to the system clipboard'), type: :warn)
    expect(chat.copy_to_clipboard).to be_nil
    chat.instance_variable_get(:@messages).load_conversation(asset('conversation.json'))
    expect(chat).to receive(:feedback).with('The last response has been successfully copied to the system clipboard.', type: :info)
    expect(chat).to receive(:perform_copy_to_clipboard).and_return nil
    expect(chat.copy_to_clipboard).to eq true
  end

  it 'can paste from clipboard' do
    expect(chat).to receive(:feedback).with('The clipboard content has been successfully copied to the chat.', type: :info)
    expect(chat).to receive(:perform_paste_from_clipboard).and_return 'test content'
    expect(chat.paste_from_clipboard).to eq 'test content'
  end
end
