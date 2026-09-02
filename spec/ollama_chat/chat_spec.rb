describe OllamaChat::Chat, protect_env: true do
  let :collection do
    :default
  end

  let :argv do
    chat_default_config
  end

  before do
    ENV['OLLAMA_CHAT_MODEL'] = 'llama3.1'
    const_conf_as(
      'OC::PAGER' => nil
    )
  end

  let :chat do
    OllamaChat::Chat.new(argv:).expose
  end

  describe 'instantiation' do
    connect_to_ollama_server(instantiate: false)

    it 'can be instantiated' do
      expect(chat).to be_a described_class
    end
  end

  describe OllamaChat::DocumentCache do
    connect_to_ollama_server(instantiate: false)

    context 'falls back to MemoryCache' do
      it 'falls back to MemoryCache' do
        expect_any_instance_of(OllamaChat::Chat).to\
          receive(:document_cache_class).and_raise(NameError)
        expect(chat.documents.cache).to be_a Documentrix::Documents::MemoryCache
      end
    end
  end

  describe OllamaChat::Information do
    connect_to_ollama_server(instantiate: false)

    it 'has progname' do
      expect(chat.progname).to eq 'ollama_chat'
    end

    it 'has user_agent' do
      expect(chat.user_agent).to match %r(\Aollama_chat/\d+\.\d+\.\d+\z)
    end

    it 'can display collection_stats' do
      chat
      expect(STDOUT).to receive(:puts).with(
        /Current Collection\n  Name: \e\[1mdefault\e\[0m\n  Status: ✅\n  Patterns: \e\[3m\e\[0m\n  #Embeddings: 0\n  #Tags: 0\n  Tags:/
      )
      expect(chat.collection_stats).to be_nil
    end

    it 'can display info' do
      chat
      expect(STDOUT).to receive(:puts).
        with(
          /
            Running\ ollama_chat\ version|
            Connected\ to\ ollama\ server|
            Current\ conversation\ model|
            Current\ embedding\ model|
            Options|
            Capabilities|
            Embedding|
            Text\ splitter|
            Documents\ database\ cache|
            output\ content|
            Streaming|
            Location|
            Document\ policy|
            Think\ mode|
            Thinking\ out\ loud|
            Voice\ output|
            Currently\ selected\ search\ engine|
            Conversation\ length|
            Tools\ support\ enabled|
            Runtime\ Information|
            languages:|
          /x
        ).at_least(1)
      expect(chat.info).to be_nil
    end

    it 'can display usage' do
      chat
      expect(STDOUT).to receive(:puts).with(/\AUsage: ollama_chat/)
      expect(chat.usage).to eq 0
    end

    it 'can display version' do
      chat
      expect(STDOUT).to receive(:puts).with(/\Aollama_chat \d+\.\d+\.\d+\z/)
      expect(chat.version).to eq 0
    end
  end

  describe '#initial_collection' do
    connect_to_ollama_server(instantiate: false)

    let(:session) { double('Session') }
    let(:config) { double('Config') }

    before do
      expect(chat).to receive(:session).and_return(session)
      expect(chat).to receive(:config).and_return(config)
    end

    it 'returns :default for invalid collection names' do
      expect(session).to receive(:current_collection).and_return(nil)
      expect(config).to receive_message_chain(:embedding, :collection).and_return('invalid/collection')
      expect(chat.initial_collection).to eq(:default)
    end

    it 'returns the collection name for valid names' do
      expect(session).to receive(:current_collection).and_return(nil)
      expect(config).to receive_message_chain(:embedding, :collection).and_return('my.valid-collection')
      expect(chat.initial_collection).to eq('my.valid-collection'.to_sym)
    end
  end
end
