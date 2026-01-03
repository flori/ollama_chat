require 'spec_helper'

describe OllamaChat::MessageOutput do
  let :chat do
    OllamaChat::Chat.new
  end

  connect_to_ollama_server

  it 'output can write to file' do
    expect(STDERR).to receive(:puts).with(/No response available to write to "foo.txt"/)
    expect(chat.output('foo.txt')).to be_nil
    chat.instance_variable_get(:@messages).load_conversation(asset('conversation.json'))
    expect(chat).to receive(:attempt_to_write_file).and_return true
    expect(STDOUT).to receive(:puts).with(/Last response was written to \"foo.txt\"./)
    expect(chat.output('foo.txt')).to eq chat
  end

  it 'pipe can write to command stdin' do
    expect(STDERR).to receive(:puts).with(/No response available to output to pipe command ".*true.*"/)
    expect(chat.pipe(`which true`)).to be_nil
    chat.instance_variable_get(:@messages).load_conversation(asset('conversation.json'))
    expect(STDOUT).to receive(:puts).with(/Last response was piped to \".*true.*\"./)
    expect(chat.pipe(`which true`)).to eq chat
  end
end
