require 'spec_helper'

RSpec.describe OllamaChat::Information do
  let :chat do
    OllamaChat::Chat.new
  end

  connect_to_ollama_server

  describe ::OllamaChat::Information::UserAgent do
    it 'has progname' do
      expect(chat.progname).to eq 'ollama_chat'
    end

    it 'has user_agent' do
      expect(chat.user_agent).to match %r(\Aollama_chat/\d+\.\d+\.\d+\z)
    end
  end

  it 'can show collection_stats' do
    expect(STDOUT).to receive(:puts).with(/Current Collection/)
    expect(chat.collection_stats).to be_nil
  end

  it 'can show info' do
    expect(STDOUT).to receive(:puts).with(/Connected to ollama server version/)
    expect(STDOUT).to receive(:puts).with(/Current conversation model is/)
    expect(STDOUT).to receive(:puts).at_least(1)
    expect(chat.info).to be_nil
  end

  it 'can show display_chat_help' do
    expect(STDOUT).to receive(:puts).with(%r(/info.*show information))
    expect(chat.display_chat_help).to be_nil
  end

  it 'can show usage' do
    expect(STDOUT).to receive(:puts).with(/Usage: ollama_chat/)
    expect(chat.usage).to eq 0
  end

  it 'can show  version' do
    expect(STDOUT).to receive(:puts).with(/^ollama_chat \d+\.\d+\.\d+$/)
    expect(chat.version).to eq 0
  end

  it 'can show server version' do
    expect(chat.server_version).to eq '6.6.6'
  end

  it 'can show server URL' do
    expect(chat.server_url).to be_a URI::HTTP
  end
end
