require 'spec_helper'

RSpec.describe OllamaChat::Chat do
  let :argv do
    []
  end

  let :chat do
    OllamaChat::Chat.new argv: argv
  end

  connect_to_ollama_server(instantiate: false)

  it 'can be instantiated' do
    expect(chat).to be_a described_class
  end

  describe OllamaChat::DocumentCache do
    context 'with MemoryCache' do
      let :argv do
        %w[ -M ]
      end

      it 'can use MemoryCache' do
        expect(chat.documents.cache).to be_a Documentrix::Documents::MemoryCache
      end
    end

    context 'falls back to MemoryCache' do
      it 'falls back to MemoryCache' do
        expect_any_instance_of(OllamaChat::Chat).to\
          receive(:document_cache_class).and_raise(NameError)
        expect(chat.documents.cache).to be_a Documentrix::Documents::MemoryCache
      end
    end
  end

  describe Documentrix::Documents do
    context 'with documents' do
      let :argv do
        %w[ -D ] << asset('example.html')
      end

      it 'Adds documents passed to app via -D option' do
        expect_any_instance_of(OllamaChat::Chat).to receive(:add_documents_from_argv).
          with([ asset('example.html') ])
        chat
      end
    end
  end

  describe OllamaChat::Information do
    it 'has progname' do
      expect(chat.progname).to eq 'ollama_chat'
    end

    it 'has user_agent' do
      expect(chat.user_agent).to match %r(\Aollama_chat/\d+\.\d+\.\d+\z)
    end

    it 'can display collection_stats' do
      chat
      expect(STDOUT).to receive(:puts).with(
        "Current Collection\n  Name: \e[1mdefault\e[0m\n  #Embeddings: 0\n  #Tags: 0\n  Tags: \n"
      )
      expect(chat.collection_stats).to be_nil
    end

    it 'can display info' do
      chat
      expect(STDOUT).to receive(:puts).
        with(
          /
            Connected\ to\ ollama\ server|
            Current\ model|
            Options|
            Embedding|
            Text\ splitter|
            Documents\ database\ cache|
            output\ content|
            Streaming|
            Location|
            Document\ policy
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
end
