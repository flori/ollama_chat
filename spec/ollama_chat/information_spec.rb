describe OllamaChat::Information do
  let :chat do
    OllamaChat::Chat.new argv: chat_default_config
  end

  connect_to_ollama_server

  before do
    const_conf_as(
      'OC::PAGER' => nil
    )
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
    expect { |b| chat.use_pager(&b) }.to yield_with_args(StringIO)
    allow(STDOUT).to receive(:print)
    expect(STDOUT).to receive(:puts).with(/Running ollama_chat version/)
    expect(STDOUT).to receive(:puts).with(/Connected to ollama server/)
    expect(STDOUT).to receive(:puts).with(/Documents database cache/)
    expect(STDOUT).to receive(:puts).with(/Currently selected search engine/)
    expect(STDOUT).to receive(:puts).with(/Current chat model is/)
    expect(STDOUT).to receive(:puts).with(/Session:/)
    expect(STDOUT).to receive(:puts).with(/Current System Prompt/)
    expect(STDOUT).to receive(:puts).with(/No persona selected/)
    expect(STDOUT).to receive(:puts).with(/Tools support enabled/)
    expect(STDOUT).to receive(:puts).with(/Runtime Information enabled/)
    expect(chat.info).to be_nil
  end

  it 'can display display_config' do
    expect(chat.config).to receive(:to_s).and_return('test configuration')
    expect { chat.send(:display_config) }.not_to raise_error
  end

  it 'can show display_chat_help' do
    expect(chat).to receive(:help_message)
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
