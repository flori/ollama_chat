require 'spec_helper'

RSpec.describe OllamaChat::Chat do
  let :argv do
    %w[ -C test ]
  end

  let :chat do
    OllamaChat::Chat.new argv: argv
  end

  connect_to_ollama_server(instantiate: false)

  it 'can be instantiated' do
    expect(chat).to be_a described_class
  end

  describe 'chat history' do
    it 'derives chat_history_filename' do
      expect(chat.send(:chat_history_filename)).to_not be_nil
    end

    it 'can save chat history' do
      expect(File).to receive(:secure_write).with(
        chat.send(:chat_history_filename),
        kind_of(String)
      )
      chat.send(:save_history)
    end

    it 'can initialize chat history' do
      expect(File).to receive(:exist?).with(chat.send(:chat_history_filename)).
        and_return true
      expect(File).to receive(:open).with(chat.send(:chat_history_filename), ?r)
      chat.send(:init_chat_history)
    end

    it 'can clear history' do
      chat
      expect(Readline::HISTORY).to receive(:clear)
      chat.send(:clear_history)
    end
  end

  context 'loading conversations' do
    let :argv do
      %w[ -C test -c ] << asset('conversation.json')
    end

    it 'dispays the last exchange of the converstation' do
      expect(chat).to receive(:interact_with_user).and_return 0
      expect(STDOUT).to receive(:puts).at_least(1)
      expect(chat.messages).to receive(:list_conversation)
      chat.start
    end
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
        %w[ -C test -D ] << asset('example.html')
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
        "Current Collection\n  Name: \e[1mtest\e[0m\n  #Embeddings: 0\n  #Tags: 0\n  Tags: \n"
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
            Current\ model|
            Options|
            Embedding|
            Text\ splitter|
            Documents\ database\ cache|
            output\ content|
            Streaming|
            Location|
            Document\ policy|
            Currently\ selected\ search\ engine
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
