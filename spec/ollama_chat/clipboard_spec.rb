require 'spec_helper'

describe OllamaChat::Clipboard do
  let :chat do
    OllamaChat::Chat.new
  end

  connect_to_ollama_server

  it 'can copy to clipboard' do
    `which pbcopy`.full? or skip 'pbcopy not in path'
    expect(STDERR).to receive(:puts).with(/No response available to copy to the system clipboard/)
    expect(chat.copy_to_clipboard).to be_nil
    chat.instance_variable_get(:@messages).load_conversation(asset('conversation.json'))
    expect(STDOUT).to receive(:puts).with(/The last response has been copied to the system clipboard/)
    expect(chat.copy_to_clipboard).to be_nil
  end

  it 'can paste from input' do
    expect(STDOUT).to receive(:puts).with(/Paste your content/)
    expect(STDIN).to receive(:read).and_return 'test input'
    expect(chat.paste_from_input).to eq 'test input'
  end
end
