describe OllamaChat::Information do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config).expose
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

  describe '#client' do
    it 'returns progname and version separated by a space' do
      expect(chat.client).to eq("ollama_chat #{OllamaChat::VERSION}")
    end
  end

  describe '#collection_descriptions' do
    it 'returns a hash of collection name to description' do
      chat::models::Collection.insert(
        name: 'zz_test', description: 'A test collection'
      )
      descs = chat.collection_descriptions
      expect(descs).to be_a(Hash)
      expect(descs['zz_test']).to eq('A test collection')
    end

    it 'returns an empty hash when no collections exist' do
      chat::models::Collection.dataset.delete
      expect(chat.collection_descriptions).to eq({})
    end
  end

  describe '#user' do
    it 'falls back to n/a when user is not set' do
      const_conf_as('OC::OLLAMA::CHAT::USER' => nil)
      expect(chat.user).to eq('n/a')
    end
  end

  describe '#infobar_message' do
    it 'returns a hash from the config' do
      expect(chat.infobar_message).to be_a(Hash)
    end
  end
end
