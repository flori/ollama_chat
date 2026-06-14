describe OllamaChat::MessageOutput do
  let :chat do
    OllamaChat::Chat.new argv: chat_default_config
  end

  connect_to_ollama_server

  it 'output can write to file' do
    expect(STDERR).to receive(:puts).with(/No response available to write to "foo.txt"/)
    expect(chat.output('foo.txt')).to be_nil
    chat.instance_variable_get(:@messages).load_conversation(asset('conversation.json'))
    expect(chat).to receive(:attempt_to_write_file).
      with('foo.txt', /YOU WANT TO KNOW ABOUT THE SKY/).and_return true
    expect(STDOUT).to receive(:puts).with(/Last response was written to "foo.txt"./)
    expect(chat.output('foo.txt')).to eq chat
  end

  it 'output can write edited content to file' do
    chat.instance_variable_get(:@messages).load_conversation(asset('conversation.json'))
    edited_content = "EDITED CONTENT"
    expect(chat).to receive(:edit_text).and_return(edited_content)
    expect(chat).to receive(:attempt_to_write_file).with('foo.txt', edited_content).and_return true
    expect(STDOUT).to receive(:puts).with(/Last response was written to "foo.txt"./)
    expect(chat.output('foo.txt', edit: true)).to eq chat
  end

  it 'pipe can write to command stdin' do
    expect(STDERR).to receive(:puts).with(/No response available to output to pipe command ".*true.*"/)
    expect(chat.pipe(`which true`)).to be_nil
    chat.instance_variable_get(:@messages).load_conversation(asset('conversation.json'))
    pipe_double = double('IO pipe')
    expect(IO).to receive(:popen).with(`which true`, ?w).and_yield(pipe_double)
    expect(pipe_double).to receive(:write).with(/YOU WANT TO KNOW ABOUT THE SKY/)
    expect(STDOUT).to receive(:puts).with(/Last response was piped to ".*true.*"./)
    expect(chat.pipe(`which true`)).to eq chat
  end

  it 'pipe can write edited content to command stdin' do
    expect(STDERR).to receive(:puts).with(/No response available to output to pipe command ".*true.*"/)
    expect(chat.pipe(`which true`, edit: true)).to be_nil
    chat.instance_variable_get(:@messages).load_conversation(asset('conversation.json'))
    edited_content = "EDITED CONTENT"
    expect(chat).to receive(:edit_text).and_return(edited_content)

    pipe_double = double('IO pipe')
    expect(IO).to receive(:popen).with(`which true`, ?w).and_yield(pipe_double)
    expect(pipe_double).to receive(:write).with(edited_content)

    expect(STDOUT).to receive(:puts).with(/Last response was piped to ".*true.*"./)
    expect(chat.pipe(`which true`, edit: true)).to eq chat
  end
end
