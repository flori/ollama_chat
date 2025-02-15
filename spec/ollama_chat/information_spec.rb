require 'spec_helper'

RSpec.describe OllamaChat::Information do
  let :chat do
    OllamaChat::Chat.new
  end

  before do
    stub_request(:get, %r(/api/tags\z)).
      to_return(status: 200, body: asset_json('api_tags.json'))
    stub_request(:post, %r(/api/show\z)).
      to_return(status: 200, body: asset_json('api_show.json'))
    stub_request(:get, %r(/api/version\z)).
      to_return(status: 200, body: asset_json('api_version.json'))
    chat
  end

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
    expect(STDOUT).to receive(:puts).with(/Current model is/)
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

  it 'can show version' do
    expect(chat.version).to eq 0
  end
end
