describe OllamaChat::Commands, protect_env: true do
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

  connect_to_ollama_server

  describe '/reconnect' do
    it 'returns :next when input is "/reconnect"' do
      expect(chat).to receive(:connect_ollama).and_return double('ollama')
      expect(chat.handle_input("/reconnect")).to eq :next
    end
  end

  describe '/copy' do
    it 'returns :next when input is "/copy"' do
      expect(chat).to receive(:copy_to_clipboard).with(edit: false)
      expect(chat.handle_input("/copy")).to eq :next
    end

    it 'returns :next when input is "/copy -e"' do
      expect(chat).to receive(:copy_to_clipboard).with(edit: 1)
      expect(chat.handle_input("/copy -e")).to eq :next
    end
  end

  describe '/paste' do
    it 'returns "pasted this" when input is "/paste"' do
      expect(chat).to receive(:paste_from_clipboard).with(edit: false).
        and_return "pasted this"
      expect(chat.handle_input("/paste")).to eq "pasted this"
    end

    it 'returns "pasted this" when input is "/paste -e"' do
      expect(chat).to receive(:paste_from_clipboard).with(edit: 1).
        and_return "pasted this"
      expect(chat.handle_input("/paste -e")).to eq "pasted this"
    end
  end

  describe '/toggle' do
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
      expect(chat).to receive(:display_chat_help)
      expect(chat.handle_input("/toggle nixda")).to eq :next
    end

    it 'returns :next when input is "/toggle embedding"' do
      expect(chat.embedding_paused).to receive(:toggle)
      expect(chat.embedding).to receive(:show)
      expect(chat.handle_input("/toggle embedding")).to eq :next
    end

    it 'returns :next when input is "/toggle markdown -y"' do
      expect(chat.markdown).to receive(:set).with(true, show: true)
      expect(chat.handle_input("/toggle markdown -y")).to eq :next
    end

    it 'returns :next when input is "/toggle markdown -n"' do
      expect(chat.markdown).to receive(:set).with(false, show: true)
      expect(chat.handle_input("/toggle markdown -n")).to eq :next
    end

    it 'returns :next when input is "/toggle stream -y"' do
      expect(chat.stream).to receive(:set).with(true, show: true)
      expect(chat.handle_input("/toggle stream -y")).to eq :next
    end

    it 'returns :next when input is "/toggle stream -n"' do
      expect(chat.stream).to receive(:set).with(false, show: true)
      expect(chat.handle_input("/toggle stream -n")).to eq :next
    end
  end

  describe '/voice' do
    it 'returns :next when input is "/voice"' do
      expect(chat).to receive(:change_voice)
      expect(chat.handle_input("/voice")).to eq :next
    end
  end

  describe '/list' do
    it 'returns :next when input is "/list(?:\\s+(\\d*))? "' do
      expect(chat.messages).to receive(:list_conversation).with(4, think_loud: true)
      expect(chat.handle_input("/list 2")).to eq :next
    end
  end

  describe '/clear' do
    it 'returns :next when input is "/clear (messages|links|history|tags|images|all)"' do
      expect(chat).to receive(:clean).with('messages')
      expect(chat.handle_input("/clear messages")).to eq :next
      expect(chat).to receive(:clean).with('links')
      expect(chat.handle_input("/clear links")).to eq :next
      expect(chat).to receive(:clean).with('history')
      expect(chat.handle_input("/clear history")).to eq :next
      expect(chat).to receive(:clean).with('tags')
      expect(chat.handle_input("/clear tags")).to eq :next
      expect(chat).to receive(:clean).with('images')
      expect(chat.handle_input("/clear images")).to eq :next
      expect(chat).to receive(:clean).with('all')
      expect(chat.handle_input("/clear all")).to eq :next
    end
  end

  describe '/last' do
    it 'returns :next when input is "/last"' do
      expect(chat.messages).to receive(:show_last)
      expect(chat.handle_input("/last")).to eq :next
    end

    it 'returns :next when input is "/last 2"' do
      expect(chat.messages).to receive(:show_last).with(2, think_loud: true, pager: true)
      expect(chat.handle_input("/last 2")).to eq :next
    end

    it 'returns :next when input is "/last -p 2"' do
      expect(chat.messages).to receive(:show_last).with(2, think_loud: true, pager: false)
      expect(chat.handle_input("/last -p 2")).to eq :next
    end
  end

  describe '/drop' do
    it 'returns :next when input is "/drop(?:\\s+(\\d*))?"' do
      expect(chat.messages).to receive(:drop).with(?2)
      expect(chat.messages).to receive(:show_last)
      expect(chat.handle_input("/drop 2")).to eq :next
    end
  end

  describe 'model command' do
    it 'returns :next when input is "/model change" with default profile' do
      expect(chat).to receive(:choose_model).and_return 'mistral'
      expect(chat).to receive(:choose_profile_for_model).with('mistral').and_return nil
      expect(chat).to receive(:use_model).with('mistral', profile: 'default')
      expect(chat.handle_input("/model change")).to eq :next
    end

    it 'returns :next when input is "/model change" with custom profile' do
      expect(chat).to receive(:choose_model).and_return 'mistral'
      expect(chat).to receive(:choose_profile_for_model).with('mistral').and_return 'foo'
      expect(chat).to receive(:use_model).with('mistral', profile: 'foo')
      expect(chat.handle_input("/model change")).to eq :next
    end

    it 'returns :next when input is "/model options" with cancel' do
      expect(chat).to receive(:choose_profile_for_model).with(nil, allow_new: true).and_return nil
      expect(chat.handle_input("/model options")).to eq :next
    end

    it 'returns :next when input is "/model options" with custom profile' do
      expect(chat).to receive(:choose_profile_for_model).with(nil, allow_new: true).and_return 'foo'
      expect(chat).to receive(:edit_model_options).with(nil, profile: 'foo')
      expect(chat.handle_input("/model options")).to eq :next
    end

    it 'returns :next when input is "/model options from session" with default profile' do
      expect(chat).to receive(:choose_profile_for_model).with(nil).and_return nil
      expect(chat).to receive(:copy_model_options_from_session).with(nil, profile: 'default')
      expect(chat.handle_input("/model options from session")).to eq :next
    end

    it 'returns :next when input is "/model options from session" with custom profile' do
      expect(chat).to receive(:choose_profile_for_model).with(nil).and_return 'foo'
      expect(chat).to receive(:copy_model_options_from_session).with(nil, profile: 'foo')
      expect(chat.handle_input("/model options from session")).to eq :next
    end

    it 'returns :next when input is "/model options to session" with default profile' do
      expect(chat).to receive(:choose_profile_for_model).with(nil).and_return nil
      expect(chat).to receive(:copy_model_options_to_session).with(nil, profile: 'default')
      expect(chat.handle_input("/model options to session")).to eq :next
    end

    it 'returns :next when input is "/model options to session" with custom profile' do
      expect(chat).to receive(:choose_profile_for_model).with(nil).and_return 'foo'
      expect(chat).to receive(:copy_model_options_to_session).with(nil, profile: 'foo')
      expect(chat.handle_input("/model options to session")).to eq :next
    end

    it 'returns :next when input is "/model options -m" with default profile' do
      expect(chat).to receive(:choose_model).and_return 'codellama'
      expect(chat).to receive(:choose_profile_for_model).with('codellama', allow_new: true).and_return 'default'
      expect(chat).to receive(:edit_model_options).with('codellama', profile: 'default')
      expect(chat.handle_input("/model options -m")).to eq :next
    end

    it 'returns :next when input is "/model options from session -m" with default profile' do
      expect(chat).to receive(:choose_model).and_return 'codellama'
      expect(chat).to receive(:choose_profile_for_model).with('codellama').and_return 'default'
      expect(chat).to receive(:copy_model_options_from_session).with('codellama', profile: 'default')
      expect(chat.handle_input("/model options from session -m")).to eq :next
    end

    it 'returns :next when input is "/model options to session -m" with default profile' do
      expect(chat).to receive(:choose_model).and_return 'codellama'
      expect(chat).to receive(:choose_profile_for_model).with('codellama').and_return nil
      expect(chat).to receive(:copy_model_options_to_session).with('codellama', profile: 'default')
      expect(chat.handle_input("/model options to session -m")).to eq :next
    end

    it 'returns :next when input is "/model options copy"' do
      expect(chat).to receive(:copy_model_options_profile).with(nil)
      expect(chat.handle_input("/model options copy")).to eq :next
    end

    it 'returns :next when input is "/model options copy -m"' do
      expect(chat).to receive(:choose_model).and_return 'codellama'
      expect(chat).to receive(:copy_model_options_profile).with('codellama')
      expect(chat.handle_input("/model options copy -m")).to eq :next
    end

    it 'returns :next when input is "/model options export"' do
      expect(chat).to receive(:export_model_options)
      expect(chat.handle_input("/model options export")).to eq :next
    end

    it 'returns :next when input is "/model options import"' do
      filename = Pathname.new('tmp/test.json')
      expect(chat).to receive(:choose_filename).with('**/*.json').and_return filename
      expect(chat).to receive(:import_model_options).with(filename)
      expect(chat.handle_input("/model options import")).to eq :next
    end

    it 'returns :next when input is "/model options import" with cancel' do
      expect(chat).to receive(:choose_filename).with('**/*.json').and_return nil
      expect(chat.handle_input("/model options import")).to eq :next
    end
  end

  describe '/session model options change' do
    it 'returns :next when input is "/session model options change"' do
      expect(chat).to receive(:choose_profile_for_model).with(nil).and_return('default')
      expect(chat).to receive(:copy_model_options_to_session).with(profile: 'default')
      expect(chat.handle_input("/session model options change")).to eq :next
    end

    it 'returns :next when input is "/session model options change -p foo"' do
      expect(chat).to receive(:copy_model_options_to_session).with(profile: 'foo')
      expect(chat.handle_input("/session model options change -p foo")).to eq :next
    end
  end

  describe '/system' do
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
  end

  describe '/regenerate' do
    it 'returns :next when input is "/regenerate"' do
      expect(STDOUT).to receive(:puts).with(/Not enough messages/)
      expect(chat.handle_input("/regenerate")).to eq :redo
    end

    it 'returns :next when input is "/regenerate -e"' do
      expect(STDOUT).to receive(:puts).with(/Not enough messages/)
      expect(chat.handle_input("/regenerate -e")).to eq :redo
    end
  end

  describe '/change response' do
    it 'returns :next when input is "/change response"' do
      expect(chat.handle_input("/change response")).to eq :next
    end
  end

  describe '/collection' do
    it 'returns :next when input is "/collection(clear|change)"' do
      expect(chat).to receive(:choose_entry)
      expect(STDOUT).to receive(:puts).with(/Exiting/)
      expect(chat.handle_input("/collection clear")).to eq :next
      expect(chat).to receive(:choose_entry)
      expect(chat).to receive(:info)
      expect(STDOUT).to receive(:puts).with(/Using collection/)
      expect(chat.handle_input("/collection change")).to eq :next
      expect(STDOUT).to receive(:puts).with(/default/)
      expect(chat.handle_input("/collection list")).to eq :next
      expect(chat).to receive(:rename_collection).with(:default)
      expect(chat.handle_input("/collection rename")).to eq :next
    end
  end

  describe '/info' do
    it 'returns :next when input is "/info"' do
      expect(chat).to receive(:info)
      expect(chat.handle_input("/info")).to eq :next
    end
  end

  describe '/document policy' do
    it 'returns :next when input is "/document policy"' do
      expect_any_instance_of(OllamaChat::StateSelectors::DatabaseStateSelector).
        to receive(:choose_entry)
      expect(chat.handle_input("/document policy")).to eq :next
    end
  end

  describe '/input' do
    context 'import' do
      it 'returns "success" when input is "/input (.+)"' do
        expect(chat).to receive(:import).with(asset('example.rb')).
          and_return 'success'
        expect(chat.handle_input("/input #{asset('example.rb')}")).to eq 'success'
      end

      it 'returns "success" when input is "/input -a -p (.+)"' do
        expect(chat).to receive(:import).with(Pathname.new(asset('example.rb'))).
          and_return 'success'
        expect(chat.handle_input("/input -a -p #{asset('*.rb')}")).to\
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

      it 'returns "success" when input is "/input summary -a -p (.+)"' do
        expect(chat).to receive(:summarize).
          with(asset_pathname('example.rb'), words: nil).
          and_return 'success'
        expect(chat.handle_input("/input summary -a -p #{asset('*.rb')}")).to\
          match(/success/)
      end

      it 'returns :next when input is "/input summary"' do
        expect(chat.handle_input("/input summary")).to eq :next
      end
    end

    context 'embedding' do
      before do
        expect(chat).to receive(:confirm?).
          with(prompt: /current collection/, yes: /\Ay/i).
          and_return true
      end

      it 'returns "success" when input is "/input embedding (.+)"' do
        expect(chat).to receive(:embed).
          with(asset('example.rb'), tags: nil).
          and_return 'success'
        expect(chat.handle_input("/input embedding #{asset('example.rb')}")).
          to eq 'success'
      end

      it 'returns "success" when input is "/input embedding -p (.+)"' do
        expect(chat).to receive(:embed).
          with(asset_pathname('example.rb'), tags: nil).
          and_return 'success'
        expect(chat.handle_input("/input embedding -a -p #{asset('*.rb')}")).
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

      it 'returns "success" when input is "/input path -a -p (.+)"' do
        expect(chat.handle_input("/input path -a -p #{asset('*.rb')}")).
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

      it 'returns "success" when input is "/input context -a -p (.+)"' do
        expect(chat).to receive(:context_spook).
          with([asset('*.rb')], all: 1).and_return 'success'
        expect(chat.handle_input("/input context -a -p #{asset('*.rb')}")).
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

  describe '/output' do
    it 'can output last response with "/output foo.md"' do
      expect(chat).to receive(:output).with('foo.md', edit: false)
      expect(chat.handle_input("/output foo.md")).to eq :next
    end

    it 'can output last response with editing with "/output -e foo.md"' do
      expect(chat).to receive(:output).with('foo.md', edit: 1)
      expect(chat.handle_input("/output -e foo.md")).to eq :next
    end
  end

  describe '/pipe' do
    it 'can pipe last response with "/pipe true"' do
      expect(chat).to receive(:pipe).with('true', edit: false)
      expect(chat.handle_input("/pipe true")).to eq :next
    end

    it 'can pipe last response with editing with "/pipe -e true"' do
      expect(chat).to receive(:pipe).with('true', edit: 1)
      expect(chat.handle_input("/pipe -e true")).to eq :next
    end
  end

  describe '/web' do
    it 'returns "the response" when input is "/web\\s+(?:(\\d+)\\s+)?(.+)"' do
      expect(chat).to receive(:web).with('23', 'query').and_return 'the response'
      expect(chat.handle_input("/web 23 query")).to eq 'the response'
    end
  end

  describe '/links' do
    it 'returns :next when input is "/links(?:\\s+(clear))?$ "' do
      expect(chat).to receive(:manage_links).with(nil)
      expect(chat.handle_input("/links")).to eq :next
      expect(chat).to receive(:manage_links).with('clear')
      expect(chat.handle_input("/links clear")).to eq :next
    end
  end

  describe 'conversation' do
    it 'returns :next when input is "/conversation save\\s+(.+)$"' do
      expect(chat).to receive(:save_conversation).with('./some_file.jsonl', clean: false)
      expect(chat.handle_input("/conversation save ./some_file.jsonl")).to eq :next
    end

    it 'returns :next when input is "/conversation save -c ./some_file.jsonl"' do
      expect(chat).to receive(:save_conversation).with('./some_file.jsonl', clean: 1)
      expect(chat.handle_input("/conversation save -c ./some_file.jsonl")).to eq :next
    end

    it 'returns :next when input is "/conversation save" without path' do
      expect { chat.handle_input("/conversation save") }.not_to raise_error
      expect(chat.handle_input("/conversation save")).to eq :next
    end

    it 'returns :next when input is "/conversation load\\s+(.+)$"' do
      expect(chat).to receive(:load_conversation).with('./some_file.jsonl')
      expect(chat.handle_input("/conversation load ./some_file.jsonl")).to eq :next
    end

    it 'returns :next when input is "/conversation load" without path' do
      expect { chat.handle_input("/conversation load") }.not_to raise_error
      expect(chat.handle_input("/conversation load")).to eq :next
    end

    it 'returns :next when input is "/conversation clean$"' do
      expect(chat).to receive(:confirm?).and_return true
      expect(chat.handle_input("/conversation clean")).to eq :next
    end

    it 'returns :next when input is "/conversation clean" and user cancels' do
      expect(chat).to receive(:confirm?).and_return false
      expect(chat.handle_input("/conversation clean")).to eq :next
    end
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

  describe '/config' do
    it 'returns :next when input is "/config"' do
      expect(chat).to receive(:display_config)
      expect(chat.handle_input("/config")).to eq :next
    end
  end

  describe '/quit' do
    it 'returns :return when input is "/quit"' do
      expect { chat.handle_input("/quit") }.to\
        raise_error(OllamaChat::OllamaChatQuitError)
    end
  end

  describe '/nixda' do
    it 'returns :next when input is "/nixda"' do
      expect(chat).to receive(:display_chat_help)
      expect(chat.handle_input("/nixda")).to eq :next
    end
  end

  describe '/help' do
    it 'returns "the help message" when input is "/help me"' do
      expect(chat).to receive(:help_message).and_return 'the help message'
      expect(chat.handle_input("/help me")).to include 'the help message'
    end
  end
end
