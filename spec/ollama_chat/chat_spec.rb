describe OllamaChat::Chat, protect_env: true do
  let :argv do
    chat_default_config(%w[ -C test ])
  end

  before do
    ENV['OLLAMA_CHAT_MODEL'] = 'llama3.1'
  end

  let :chat do
    OllamaChat::Chat.new(argv: argv).expose
  end

  describe 'instantiation' do
    connect_to_ollama_server(instantiate: false)

    it 'can be instantiated' do
      expect(chat).to be_a described_class
    end
  end

  describe 'handle_input' do
    connect_to_ollama_server

    it 'returns :next when input is "/reconnect"' do
      expect(chat).to receive(:connect_ollama).and_return double('ollama')
      expect(chat.handle_input("/reconnect")).to eq :next
    end

    it 'returns :next when input is "/copy"' do
      expect(chat).to receive(:copy_to_clipboard)
      expect(chat.handle_input("/copy")).to eq :next
    end

    it 'returns "pasted this" when input is "/paste"' do
      expect(chat).to receive(:paste_from_clipboard).and_return "pasted this"
      expect(chat.handle_input("/paste")).to eq "pasted this"
    end

    it 'returns :next when input is "/toggle markdown"' do
      expect(chat.markdown).to receive(:toggle)
      expect(chat.handle_input("/toggle markdown")).to eq :next
    end

    it 'returns :next when input is "/toggle stream"' do
      expect(chat.stream).to receive(:toggle)
      expect(chat.handle_input("/toggle stream")).to eq :next
    end

    it 'returns :next when input is "/toggle location"' do
      expect(chat.location).to receive(:toggle)
      expect(chat.handle_input("/toggle location")).to eq :next
    end

    it 'returns :next when input is "/toggle runtime_info"' do
      expect(chat.runtime_info).to receive(:toggle)
      expect(chat.handle_input("/toggle runtime_info")).to eq :next
    end

    it 'returns :next when input is "/toggle voice"' do
      expect(chat.voice).to receive(:toggle)
      expect(chat.handle_input("/toggle voice")).to eq :next
    end

    it 'returns :next when input is "/toggle nixda"' do
      expect_any_instance_of(OllamaChat::Switches::Switch).not_to receive(:toggle)
      expect(chat).to receive(:display_chat_help)
      expect(chat.handle_input("/toggle nixda")).to eq :next
    end

    it 'returns :next when input is "/toggle embedding"' do
      expect(chat.embedding_paused).to receive(:toggle)
      expect(chat.embedding).to receive(:show)
      expect(chat.handle_input("/toggle embedding")).to eq :next
    end

    it 'returns :next when input is "/voice"' do
      expect(chat).to receive(:change_voice)
      expect(chat.handle_input("/voice")).to eq :next
    end

    it 'returns :next when input is "/list(?:\s+(\d*))? "' do
      expect(chat.messages).to receive(:list_conversation).with(4)
      expect(chat.handle_input("/list 2")).to eq :next
    end

    it 'returns :next when input is "/clear (messages|links|history|all)"' do
      expect(chat).to receive(:clean).with('messages')
      expect(chat.handle_input("/clear messages")).to eq :next
      expect(chat).to receive(:clean).with('links')
      expect(chat.handle_input("/clear links")).to eq :next
      expect(chat).to receive(:clean).with('history')
      expect(chat.handle_input("/clear history")).to eq :next
      expect(chat).to receive(:clean).with('all')
      expect(chat.handle_input("/clear all")).to eq :next
    end

    it 'returns :next when input is "/last"' do
      expect(chat.messages).to receive(:show_last)
      expect(chat.handle_input("/last")).to eq :next
    end

    it 'returns :next when input is "/last\s+(\d+)"' do
      expect(chat.messages).to receive(:show_last).with(2)
      expect(chat.handle_input("/last 2")).to eq :next
    end

    it 'returns :next when input is "/drop(?:\s+(\d*))?"' do
      expect(chat.messages).to receive(:drop).with(?2)
      expect(chat.messages).to receive(:show_last)
      expect(chat.handle_input("/drop 2")).to eq :next
    end

    it 'returns :next when input is "/model"' do
      expect(chat).to receive(:choose_model).and_return 'llama3.1'
      expect(chat.handle_input("/model")).to eq :next
    end

    it 'returns :next when input is "/system change"' do
      expect(chat).to receive(:change_system_prompt).with(nil)
      expect(chat.messages).to receive(:show_system_prompt)
      expect(chat.handle_input("/system change")).to eq :next
    end

    it 'returns :next when input is "/system"' do
      expect(chat).not_to receive(:change_system_prompt)
      expect(chat.messages).to receive(:show_system_prompt)
      expect(chat.handle_input("/system")).to eq :next
    end

    it 'returns :next when input is "/revise"' do
      expect(STDOUT).to receive(:puts).with(/Not enough messages/)
      expect(chat.handle_input("/revise")).to eq :redo
    end

    it 'returns :next when input is "/revise edit"' do
      expect(STDOUT).to receive(:puts).with(/Not enough messages/)
      expect(chat.handle_input("/revise edit")).to eq :redo
    end

    it 'returns :next when input is "/change_response"' do
      expect(chat.handle_input("/change_response")).to eq :next
    end

    it 'returns :next when input is "/collection(clear|change)"' do
      expect(OllamaChat::Utils::Chooser).to receive(:choose)
      expect(STDOUT).to receive(:puts).with(/Exiting/)
      expect(chat.handle_input("/collection clear")).to eq :next
      expect(OllamaChat::Utils::Chooser).to receive(:choose)
      expect(chat).to receive(:info)
      expect(STDOUT).to receive(:puts).with(/./)
      expect(chat.handle_input("/collection change")).to eq :next
    end

    it 'returns :next when input is "/info"' do
      expect(chat).to receive(:info)
      expect(chat.handle_input("/info")).to eq :next
    end

    it 'returns :next when input is "/document_policy"' do
      expect_any_instance_of(OllamaChat::StateSelectors::StateSelector).to\
        receive(:choose)
      expect(chat.handle_input("/document_policy")).to eq :next
    end

    describe '/input' do
      context 'import' do
        it 'returns "success" when input is "/input (.+)"' do
          expect(chat).to receive(:import).with(asset('example.rb')).
            and_return 'success'
          expect(chat.handle_input("/input #{asset('example.rb')}")).to eq 'success'
        end

        it 'returns "success" when input is "/input -a pattern (.+)"' do
          expect(chat).to receive(:import).with(Pathname.new(asset('example.rb'))).
            and_return 'success'
          expect(chat.handle_input("/input -a pattern #{asset('*.rb')}")).to\
            match(/success/)
        end

        it 'returns :next when input is "/input"' do
          expect(chat.handle_input("/input")).to eq :next
        end
      end

      context 'summary' do
        it 'returns "success" when input is "/input summary -w 23 ./some/file' do
          expect(chat).to receive(:summarize).with(asset('example.rb'), words: '23').
            and_return 'success'
          expect(chat.handle_input("/input summary -w 23 #{asset('example.rb')}")).
            to eq 'success'
        end

        it 'returns "success" when input is "/input summary -a pattern (.+)"' do
          expect(chat).to receive(:summarize).
            with(asset_pathname('example.rb'), words: nil).
            and_return 'success'
          expect(chat.handle_input("/input summary -a pattern #{asset('*.rb')}")).to\
            match(/success/)
        end

        it 'returns :next when input is "/input summary"' do
          expect(chat.handle_input("/input summary")).to eq :next
        end
      end

      context 'embedding' do
        it 'returns "success" when input is "/input embedding (.+)"' do
          expect(chat).to receive(:embed).with(asset('example.rb')).
            and_return 'success'
          expect(chat.handle_input("/input embedding #{asset('example.rb')}")).
            to eq 'success'
        end

        it 'returns "success" when input is "/input embedding pattern (.+)"' do
          expect(chat).to receive(:embed).with(asset_pathname('example.rb')).
            and_return 'success'
          expect(chat.handle_input("/input embedding -a pattern #{asset('*.rb')}")).
            to match(/success/)
        end

        it 'returns :next when input is "/input embedding"' do
          expect(chat.handle_input("/input embedding")).to eq :next
        end
      end

      context 'path' do
        it 'returns "success" when input is "/input path (.+)"' do
          expect(chat.handle_input("/input path #{asset('example.rb')}")).
            to match(/puts "Hello World!/)
        end

        it 'returns "success" when input is "/input path -a pattern (.+)"' do
          expect(chat.handle_input("/input path -a pattern #{asset('*.rb')}")).
            to match(/puts "Hello World!/)
        end

        it 'returns :next when input is "/input path"' do
          expect(chat.handle_input("/input path")).to eq :next
        end
      end

      context 'context' do
        it 'returns "success" when input is "/input context (.+)"' do
          expect(chat).to receive(:context_spook).
            with([asset('example.rb')], all: true).and_return('success')
          expect(chat.handle_input("/input context #{asset('example.rb')}")).to eq 'success'
        end

        it 'returns "success" when input is "/input context -a pattern (.+)"' do
          expect(chat).to receive(:context_spook).
            with([asset('*.rb')], all: 1).and_return 'success'
          expect(chat.handle_input("/input context -a pattern #{asset('*.rb')}")).
            to eq 'success'
        end

        it 'returns :next when input is "/input context" with "success"' do
          expect(chat).to receive(:context_spook).and_return 'success'
          expect(chat.handle_input("/input context")).to eq 'success'
        end

        it 'returns :next when input is "/input context" without choosing' do
          expect(chat).to receive(:context_spook).and_return nil
          expect(chat.handle_input("/input context")).to eq :next
        end
      end
    end

    it 'returns "the response" when input is "/web\s+(?:(\d+)\s+)?(.+)"' do
      expect(chat).to receive(:web).with('23', 'query').and_return 'the response'
      expect(chat.handle_input("/web 23 query")).to eq 'the response'
    end

    it 'returns :next when input is "/save\s+(.+)$"' do
      expect(chat.messages).to receive(:save_conversation).with('./some_file')
      expect(chat.handle_input("/save ./some_file")).to eq :next
    end

    it 'returns :next when input is "/links(?:\s+(clear))?$" ' do
      expect(chat).to receive(:manage_links).with(nil)
      expect(chat.handle_input("/links")).to eq :next
      expect(chat).to receive(:manage_links).with('clear')
      expect(chat.handle_input("/links clear")).to eq :next
    end

    it 'returns :next when input is "/load\s+(.+)$"' do
      expect(chat.messages).to receive(:load_conversation).with('./some_file')
      expect(chat.handle_input("/load ./some_file")).to eq :next
    end

    describe 'tools' do
      it 'returns :next when input is "/tools"' do
        expect(chat).to receive(:list_tools)
        expect(chat.handle_input("/tools")).to eq :next
      end

      it 'returns :next when input is "/tools enable"' do
        expect(chat).to receive(:enable_tool)
        expect(chat.handle_input("/tools enable")).to eq :next
      end

      it 'returns :next when input is "/tools disable"' do
        expect(chat).to receive(:disable_tool)
        expect(chat.handle_input("/tools disable")).to eq :next
      end
    end

    it 'returns :next when input is "/config"' do
      expect(chat).to receive(:display_config)
      expect(chat.handle_input("/config")).to eq :next
    end

    it 'returns :return when input is "/quit"' do
      expect(STDOUT).to receive(:puts).with(/Goodbye/)
      expect(chat.handle_input("/quit")).to eq :return
    end

    it 'returns :next when input is "/nixda"' do
      expect(chat).to receive(:display_chat_help)
      expect(chat.handle_input("/nixda")).to eq :next
    end

    it 'returns "the help message" when input is "/help me"' do
      expect(chat).to receive(:help_message).and_return 'the help message'
      expect(chat.handle_input("/help me")).to include 'the help message'
    end
  end

  describe 'chat history' do
    connect_to_ollama_server(instantiate: false)

    it 'can save chat history' do
      expect(File).to receive(:secure_write).with(
        OC::OLLAMA::CHAT::HISTORY, kind_of(String)
      )
      chat.save_history
    end

    it 'can initialize chat history' do
      expect(OC::OLLAMA::CHAT::HISTORY).to receive(:exist?).and_return true
      expect(OC::OLLAMA::CHAT::HISTORY).to receive(:read).and_return '{}'
      expect_any_instance_of(described_class).to receive(:init_chat_history).
        and_call_original
      chat
    end

    it 'can clear history' do
      chat
      expect(Readline::HISTORY).to receive(:clear)
      chat.clear_history
    end
  end

  context 'loading conversations' do
    connect_to_ollama_server(instantiate: false)

    let :argv do
      chat_default_config(%w[ -C test -c ] << asset('conversation.json'))
    end

    it 'dispays the last exchange of the converstation' do
      expect(chat).to receive(:interact_with_user).and_return 0
      expect(STDOUT).to receive(:puts).at_least(1)
      chat.start
    end
  end

  describe OllamaChat::DocumentCache do
    connect_to_ollama_server(instantiate: false)

    context 'with MemoryCache' do

      let :argv do
        chat_default_config(%w[ -M ])
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
    connect_to_ollama_server(instantiate: false)

      let :argv do
        chat_default_config(%w[ -C test -D ] << asset('example.html'))
      end

      it 'Adds documents passed to app via -D option' do
        expect_any_instance_of(OllamaChat::Chat).to receive(:add_documents_from_argv).
          with([ asset('example.html') ])
        chat
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
end
