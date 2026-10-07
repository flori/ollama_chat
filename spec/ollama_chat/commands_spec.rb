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

    it 'pastes from stdin with -i' do
      expect(chat).to receive(:paste_from_stdin).with(edit: false)
        .and_return "stdin content"
      expect(chat.handle_input("/paste -i")).to eq "stdin content"
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

    it 'returns :next when input is "/toggle memory_trigger"' do
      expect(chat.memory_trigger).to receive(:toggle)
      expect(chat.handle_input("/toggle memory_trigger")).to eq :next
    end

    it 'returns :next when input is "/toggle memory_trigger -y"' do
      expect(chat.memory_trigger).to receive(:set).with(true, show: true)
      expect(chat.handle_input("/toggle memory_trigger -y")).to eq :next
    end

    it 'returns :next when input is "/toggle memory_trigger -n"' do
      expect(chat.memory_trigger).to receive(:set).with(false, show: true)
      expect(chat.handle_input("/toggle memory_trigger -n")).to eq :next
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

    it 'speaks last message with -v' do
      expect(chat.messages).to receive(:speak_last).with(1)
      expect(chat.handle_input("/last -v")).to eq :next
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

    it 'returns :next when input is "/model options import -p /foo/**/*.json"' do
      filename = Pathname.new('/foo/bar.json')
      expect(chat).to receive(:choose_filename).with('/foo/**/*.json').and_return filename
      expect(chat).to receive(:import_model_options).with(filename)
      expect(chat.handle_input("/model options import -p /foo/**/*.json")).to eq :next
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

  describe '/session model options' do
    it 'returns :next and delegates to edit_session_model_options' do
      expect(chat).to receive(:edit_session_model_options)
      expect(chat.handle_input("/session model options")).to eq :next
    end
  end

  describe '/session trigger edit' do
    it 'returns :next and delegates to edit_session_trigger' do
      expect(chat).to receive(:edit_session_trigger)
      expect(chat.handle_input("/session trigger edit")).to eq :next
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
      expect(chat).to receive(:feedback).with(a_string_including('Not enough messages'), type: :warn)
      expect(chat.handle_input("/regenerate")).to eq :redo
    end

    it 'returns :next when input is "/regenerate -e"' do
      expect(chat).to receive(:feedback).with(a_string_including('Not enough messages'), type: :warn)
      expect(chat.handle_input("/regenerate -e")).to eq :redo
    end

    it 'drops last exchange and returns user content' do
      chat.messages << OllamaChat::Message.new(
        role: 'user', content: 'regen me'
      )
      expect(chat.messages).to receive(:drop).with(1)
      expect(chat.handle_input('/regenerate')).to eq 'regen me'
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
      expect(chat).to receive(:feedback).with(a_string_including('Exiting'))
      expect(chat.handle_input("/collection clear tags")).to eq :next
      expect(chat).to receive(:choose_entry)
      expect(chat).to receive(:info)
      expect(chat).to receive(:feedback).with(a_string_including('Using collection'), type: :info)
      expect(chat.handle_input("/collection change")).to eq :next
      expect(STDOUT).to receive(:puts).with(/default/)
      expect(chat.handle_input("/collection list")).to eq :next
      expect(chat).to receive(:rename_collection).with(:default)
      expect(chat.handle_input("/collection rename")).to eq :next
    end

    it 'routes bare "/collection clear" to clear_whole_collection' do
      expect(chat).to receive(:clear_whole_collection)
      expect(chat.handle_input("/collection clear")).to eq :next
    end

    it 'returns :next when input is "/collection query"' do
      expect(chat).to receive(:query_collection).with(edit: false, rerank: false)
      expect(chat.handle_input("/collection query")).to eq :next
    end

    it 'returns :next when input is "/collection query -e"' do
      expect(chat).to receive(:query_collection).with(edit: 1, rerank: false)
      expect(chat.handle_input("/collection query -e")).to eq :next
    end

    it 'returns :next when input is "/collection query -r"' do
      expect(chat).to receive(:query_collection).with(edit: false, rerank: 1)
      expect(chat.handle_input("/collection query -r")).to eq :next
    end

    it 'returns :next when input is "/collection query -e -r"' do
      expect(chat).to receive(:query_collection).with(edit: 1, rerank: 1)
      expect(chat.handle_input("/collection query -e -r")).to eq :next
    end
    it 'returns :next when input is "/collection" (stats)' do
      expect(chat).to receive(:collection_stats)
      expect(chat.handle_input("/collection")).to eq :next
    end

    it 'returns :next when "/collection update" has no changes' do
      expect(chat).to receive(:update_collection).with(:default)
        .and_return nil
      expect(chat.handle_input("/collection update")).to eq :next
    end

    it 'returns results when "/collection update" has content' do
      expect(chat).to receive(:update_collection).with(:default)
        .and_return 'updated 3'
      expect(chat.handle_input("/collection update")).to eq 'updated 3'
    end

    it 'returns :next when input is "/collection new"' do
      expect(chat).to receive(:create_collection)
      expect(chat.handle_input("/collection new")).to eq :next
    end

    it 'returns :next when input is "/collection edit"' do
      expect(chat).to receive(:edit_collection)
      expect(chat.handle_input("/collection edit")).to eq :next
    end

    it 'returns :next when input is "/collection delete"' do
      expect(chat).to receive(:delete_collection)
      expect(chat.handle_input("/collection delete")).to eq :next
    end

    it 'aggregates results for "/collection update all"' do
      expect(chat).to receive(:all_collections)
        .and_return(double(pluck: ['default']))
      expect(chat).to receive(:update_collection).with('default')
        .and_return 'ok'
      expect(chat.handle_input("/collection update all")).to eq "ok\n"
    end
  end

  describe '/memory' do
    it 'returns :next when input is "/memory dump ./some_file.jsonl"' do
      expect(chat).to receive(:memory_dump).with('./some_file.jsonl')
      expect(chat.handle_input("/memory dump ./some_file.jsonl")).to eq :next
    end

    it 'returns :next when input is "/memory dump" without path' do
      expect(chat).to receive(:memory_dump).with(nil)
      expect(chat.handle_input("/memory dump")).to eq :next
    end

    it 'returns :next when input is "/memory restore ./some_file.jsonl"' do
      expect(chat).to receive(:memory_restore).with('./some_file.jsonl')
      expect(chat.handle_input("/memory restore ./some_file.jsonl")).to eq :next
    end

    it 'returns :next when input is "/memory restore" without path' do
      expect(chat).to receive(:memory_restore).with(nil)
      expect(chat.handle_input("/memory restore")).to eq :next
    end

    it 'passes a path containing spaces' do
      expect(chat).to receive(:memory_dump)
        .with('./my memory dump.jsonl')
      expect(chat.handle_input("/memory dump ./my memory dump.jsonl")).to eq :next
    end
  end

  describe '/info' do
    it 'returns :next when input is "/info"' do
      expect(chat).to receive(:info)
      expect(chat.handle_input("/info")).to eq :next
    end
    it 'returns :next when input is "/info session"' do
      expect(chat).to receive(:info_session)
      expect(chat.handle_input("/info session")).to eq :next
    end

    it 'returns :next when input is "/info model"' do
      expect(chat).to receive(:info_model)
      expect(chat.handle_input("/info model")).to eq :next
    end

    it 'returns :next when input is "/info runtime"' do
      expect(chat).to receive(:info_runtime)
      expect(chat.handle_input("/info runtime")).to eq :next
    end

    it 'returns :next when input is "/info rag"' do
      expect(chat).to receive(:info_rag)
      expect(chat.handle_input("/info rag")).to eq :next
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
        expect(chat).to receive(:import).with(asset('example.rb'), language: nil).
          and_return 'success'
        expect(chat.handle_input("/input #{asset('example.rb')}")).to eq 'success'
      end

      it 'returns "success" when input is "/input -a -p (.+)"' do
        expect(chat).to receive(:import).with(Pathname.new(asset('example.rb')), language: nil).
          and_return 'success'
        expect(chat.handle_input("/input -a -p #{asset('*.rb')}")).to\
          match(/success/)
      end

      it 'returns :next when input is "/input"' do
        expect(chat.handle_input("/input")).to eq :next
      end

      it 'strips ANSI codes with -m' do
        colored = "\e[31mred text\e[0m"
        expect(chat).to receive(:import).with(asset('example.rb'), language: nil).
          and_return colored
        expect(chat.handle_input("/input -m #{asset('example.rb')}"))
          .to eq 'red text'
      end
    end

    context 'summary' do
      it 'returns "success" when input is "/input summary -w 23 ./some/file' do
        expect(chat).to receive(:summarize).with(asset('example.rb'), words: '23', instruction: nil).
          and_return 'success'
        expect(chat.handle_input("/input summary -w 23 #{asset('example.rb')}")).
          to eq 'success'
      end

      it 'returns "success" when input is "/input summary -a -p (.+)"' do
        expect(chat).to receive(:summarize).
          with(asset_pathname('example.rb'), words: nil, instruction: nil).
          and_return 'success'
        expect(chat.handle_input("/input summary -a -p #{asset('*.rb')}")).to\
          match(/success/)
      end

      it 'returns :next when input is "/input summary"' do
        expect(chat.handle_input("/input summary")).to eq :next
      end

      it 'passes instruction from ask? when -i is used' do
        expect(chat).to receive(:ask?).and_return('focus on breaking changes')
        expect(chat).to receive(:summarize).
          with(asset('example.rb'), words: nil, instruction: 'focus on breaking changes').
          and_return 'success'
        expect(chat.handle_input("/input summary -i #{asset('example.rb')}"))
          .to eq 'success'
      end

      it 'passes nil instruction when -i ask? returns empty' do
        expect(chat).to receive(:ask?).and_return('')
        expect(chat).to receive(:summarize).
          with(asset('example.rb'), words: nil, instruction: nil).
          and_return 'success'
        expect(chat.handle_input("/input summary -i #{asset('example.rb')}"))
          .to eq 'success'
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
        expect(chat).to receive(:bulk_embed_sources).
          with(anything).
          and_return [ 'success' ]
        expect(chat.handle_input("/input embedding -a -p #{asset('*.rb')}"))
          .to eq [ 'success' ]
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

      it 'accepts -m and returns file content' do
        expect(chat.handle_input("/input path -m #{asset('example.rb')}"))
          .to match(/puts "Hello World!/)
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

  describe '/prompt' do
    context 'delegation subcommands' do
      before do
        allow(chat).to receive(:choose_prompt_context).and_return 'prompt'
      end

      it 'routes each subcommand to its PromptManagement method' do
        expect(chat).to receive(:list_prompts).with(context: 'prompt')
        expect(chat.handle_input('/prompt list')).to eq :next
        expect(chat).to receive(:info_prompt).with(context: 'prompt')
        expect(chat.handle_input('/prompt info')).to eq :next
        expect(chat).to receive(:add_new_prompt).with(context: 'prompt')
        expect(chat.handle_input('/prompt add')).to eq :next
        expect(chat).to receive(:choose_and_edit_prompt).with(context: 'prompt')
        expect(chat.handle_input('/prompt edit')).to eq :next
        expect(chat).to receive(:duplicate_prompt).with(context: 'prompt')
        expect(chat.handle_input('/prompt duplicate')).to eq :next
        expect(chat).to receive(:rename_prompt).with(context: 'prompt')
        expect(chat.handle_input('/prompt rename')).to eq :next
        expect(chat).to receive(:export_prompt).with(context: 'prompt')
        expect(chat.handle_input('/prompt export')).to eq :next
        expect(chat).to receive(:prompt_sync).with(context: 'prompt')
        expect(chat.handle_input('/prompt sync')).to eq :next
      end

      it 'routes delete to choose_and_delete_prompt' do
        expect(chat).to receive(:choose_and_delete_prompt)
          .with(context: 'prompt', force: false)
        expect(chat.handle_input('/prompt delete')).to eq :next
      end

      it 'honours the -c flag without opening the context chooser' do
        expect(chat).not_to receive(:choose_prompt_context)
        expect(chat).to receive(:list_prompts).with(context: 'system')
        expect(chat.handle_input('/prompt list -c system')).to eq :next
      end
    end

    context 'bare /prompt (response template)' do
      it 'prefills the template and increments the use count' do
        expect(chat).to receive(:choose_prompt)
          .with(
            prompt: 'Which template shall guide the next response? %s',
            context: 'prompt',
            count:   true
          ).and_return 'my template'
        expect(chat.handle_input('/prompt')).to eq :next
      end

      it 'feeds the edited template back with -e' do
        expect(chat).to receive(:choose_prompt)
          .with(
            prompt: 'Which template shall guide the next response? %s',
            context: 'prompt',
            count:   true
          ).and_return 'raw'
        expect(chat).to receive(:edit_text).with('raw').and_return 'edited'
        expect(chat.handle_input('/prompt -e')).to eq 'edited'
      end
    end

    context 'reset (restore to shipped default)' do
      it 'resets the chosen prompt to its default' do
        expect(chat).to receive(:choose_prompt_context).and_return 'prompt'
        prompt = double('Prompt', name: 'my_prompt')
        expect(chat).to receive(:choose_prompt)
          .with(
            default: true,
            context: 'prompt',
            prompt:  'Which prompt needs to be restored to its origin? %s'
          ).and_return prompt
        expect(chat).to receive(:reset_prompt_to_default)
          .with('my_prompt', context: 'prompt').and_return true
        expect(chat.handle_input('/prompt reset')).to eq :next
      end
    end

    context 'reset count' do
      it 'resets counters in the prompt context only, no chooser' do
        expect(chat).not_to receive(:choose_prompt_context)
        expect(chat).to receive(:choose_and_reset_count)
          .with(context: 'prompt')
        expect(chat.handle_input('/prompt reset count')).to eq :next
      end

      it 'ignores -c (counters only exist in the prompt context)' do
        expect(chat).not_to receive(:choose_prompt_context)
        expect(chat).to receive(:choose_and_reset_count)
          .with(context: 'prompt')
        expect(chat.handle_input('/prompt reset count -c system')).to eq :next
      end
    end

    context 'import' do
      it 'imports a prompt from a file' do
        expect(chat).to receive(:choose_prompt_context).and_return 'prompt'
        expect(chat).to receive(:import_prompt)
          .with('./some_file.md', context: 'prompt')
        expect(chat.handle_input('/prompt import ./some_file.md')).to eq :next
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

    it 'passes nil count when no number given' do
      expect(chat).to receive(:web).with(nil, 'query')
        .and_return 'the response'
      expect(chat.handle_input("/web query")).to eq 'the response'
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

  describe '/conversation' do
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

    it 'returns :next when input is "/conversation compact"' do
      expect(chat).to receive(:compact_with_retry)
      expect(chat.handle_input("/conversation compact")).to eq :next
    end

    it 'returns :next when input is "/conversation compact summary"' do
      expect(chat).to receive(:show_compaction_summary)
      expect(chat.handle_input("/conversation compact summary")).to eq :next
    end

    it 'returns :next when input is "/conversation summarize"' do
      expect(chat).to receive(:summarize_conversation)
        .with(sentence: false)
      expect(chat.handle_input("/conversation summarize")).to eq :next
    end

    it 'returns :next when input is "/conversation summarize -s"' do
      expect(chat).to receive(:summarize_conversation)
        .with(sentence: 1)
      expect(chat.handle_input("/conversation summarize -s")).to eq :next
    end

    it 'returns :next when input is "/conversation report"' do
      expect(chat).to receive(:report_conversation)
      expect(chat.handle_input("/conversation report")).to eq :next
    end
  end

  describe '/tools' do
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
    it 'returns :next when input is "/tools on"' do
      expect(chat.tools_support).to receive(:set).with(true, show: true)
      expect(chat.handle_input("/tools on")).to eq :next
    end

    it 'returns :next when input is "/tools off"' do
      expect(chat.tools_support).to receive(:set).with(false, show: true)
      expect(chat.handle_input("/tools off")).to eq :next
    end
  end

  describe '/config' do
    it 'returns :next when input is "/config"' do
      expect(chat).to receive(:display_config)
      expect(chat.handle_input("/config")).to eq :next
    end

    it 'returns :next when input is "/config edit"' do
      expect(chat).to receive(:edit_config)
      expect(chat.handle_input("/config edit")).to eq :next
    end

    it 'returns :next when input is "/config reload"' do
      expect(chat).to receive(:reload_config)
      expect(chat.handle_input("/config reload")).to eq :next
    end

    it 'returns :next when input is "/config diff"' do
      expect(chat).to receive(:diff_config)
      expect(chat).to receive(:reload_config)
      expect(chat.handle_input("/config diff")).to eq :next
    end
    it 'returns :next when input is "/config env"' do
      expect(OC).to receive(:view)
      expect(chat.handle_input("/config env")).to eq :next
    end
  end

  describe '/persona' do
    it 'will get examples later'
  end

  describe '/session' do
    it 'returns :next and shows info when bare' do
      expect(chat).to receive(:info_session)
      expect(chat.handle_input('/session')).to eq :next
    end

    it 'returns :next and lists sessions' do
      expect(chat).to receive(:list_sessions)
      expect(chat.handle_input('/session list')).to eq :next
    end

    it 'returns :next and creates new session' do
      expect(chat).to receive(:set_new_session)
      expect(chat.handle_input('/session new')).to eq :next
    end

    it 'returns :next and duplicates session' do
      expect(chat).to receive(:duplicate_session)
      expect(chat.handle_input('/session duplicate')).to eq :next
    end

    it 'returns :next and deletes session' do
      expect(chat).to receive(:delete_session)
      expect(chat.handle_input('/session delete')).to eq :next
    end

    it 'returns :next and renames session' do
      expect(chat).to receive(:rename_session)
      expect(chat.handle_input('/session rename')).to eq :next
    end

    it 'returns :next and changes session by name' do
      expect(chat).to receive(:change_session).with('my_session')
      expect(chat.handle_input('/session change my_session')).to eq :next
    end

    it 'returns :next and changes to previous session' do
      expect(chat).to receive(:previous_session)
        .and_return(double('Session', id: 'abc123'))
      expect(chat).to receive(:change_session).with('abc123')
      expect(chat.handle_input('/session previous')).to eq :next
    end

    it 'gives feedback when no previous session exists' do
      expect(chat).to receive(:previous_session).and_return nil
      expect(chat).to receive(:feedback)
        .with(a_string_including('No previous session'), type: :info)
      expect(chat.handle_input('/session previous')).to eq :next
    end
  end

  describe '/favourite' do
    it 'adds a favourite for each type' do
      %w[model prompt system persona suggest].each do |type|
        expect(chat).to receive(:add_favourite).with(type)
        expect(chat.handle_input("/favourite add #{type}")).to eq :next
      end
    end

    it 'deletes a favourite for each type' do
      %w[model prompt system persona suggest].each do |type|
        expect(chat).to receive(:delete_favourite).with(type)
        expect(chat.handle_input("/favourite delete #{type}")).to eq :next
      end
    end
  end

  describe '/context_format' do
    it 'returns :next and opens the chooser' do
      expect(chat.context_format).to receive(:choose)
      expect(chat.handle_input('/context_format')).to eq :next
    end
  end

  describe '/suggest' do
    it 'returns :next when input is "/suggest"' do
      expect(chat).to receive(:suggest_prompts).with(edit: false)
        .and_return nil
      expect(chat.handle_input('/suggest')).to eq :next
    end

    it 'returns :next when input is "/suggest -e"' do
      expect(chat).to receive(:suggest_prompts).with(edit: 1)
        .and_return nil
      expect(chat.handle_input('/suggest -e')).to eq :next
    end
  end

  describe '/think' do
    it 'returns :next and opens the chooser' do
      expect(chat.think_mode).to receive(:choose)
      expect(chat.handle_input('/think')).to eq :next
    end
  end

  describe '/character' do
    it 'returns :next when no file is chosen' do
      expect(chat).to receive(:choose_filename).and_return nil
      expect(chat.handle_input('/character info')).to eq :next
    end

    it 'returns :next when file does not exist' do
      expect(chat.handle_input(
        '/character info /nonexistent_xyz.json'
      )).to eq :next
    end

    it 'returns :next for unsupported file extension' do
      expect(chat.handle_input(
        "/character info #{asset('example.rb')}"
      )).to eq :next
    end

    context 'with a JSON character file' do
      let(:char_file) do
        path = Pathname.new('tmp/spec_character_test.json')
        path.dirname.mkpath
        path.write('{"name": "TestChar"}')
        path
      end

      it 'info renders YAML in pager' do
        expect(chat).to receive(:use_pager)
          .and_yield(double('output', puts: true))
        expect(chat.handle_input(
          "/character info #{char_file}"
        )).to eq :next
      end

      it 'load returns raw JSON content' do
        expect(chat.handle_input(
          "/character load #{char_file}"
        )).to eq '{"name": "TestChar"}'
      end

      it 'import delegates to import_persona_from_json' do
        expect(chat).to receive(:import_persona_from_json)
          .with('{"name": "TestChar"}').and_return 'TestChar'
        expect(chat).to receive(:feedback)
          .with(a_string_including('TestChar'), type: :info)
        expect(chat.handle_input(
          "/character import #{char_file}"
        )).to eq :next
      end
    end

    context 'with a PNG character file' do
      let(:char_png) do
        path = Pathname.new('tmp/spec_character_test.png')
        path.dirname.mkpath
        path.write('fake png data')
        path
      end

      it 'load extracts metadata from PNG' do
        expect(OllamaChat::Utils::PNGMetadataExtractor)
          .to receive(:extract_character)
          .and_return('{"name": "PNGChar"}')
        expect(chat.handle_input(
          "/character load #{char_png}"
        )).to eq '{"name": "PNGChar"}'
      end
    end
  end

  describe '/compose' do
    it 'returns :next when editor produces empty content' do
      expect(chat).to receive(:edit_text).and_return ''
      expect(chat.handle_input('/compose')).to eq :next
    end

    it 'returns the edited content when non-empty' do
      expect(chat).to receive(:edit_text).and_return 'hello world'
      expect(chat.handle_input('/compose')).to eq 'hello world'
    end

    it 'prefills blockquote with -r and an assistant message' do
      chat.messages << OllamaChat::Message.new(
        role: 'assistant', content: "line one\nline two"
      )
      expect(chat).to receive(:edit_text)
        .with("> line one\n> line two\n\n").and_return 'my reply'
      expect(chat.handle_input('/compose -r')).to eq 'my reply'
    end

    it 'warns and skips edit with -r but no assistant message' do
      expect(chat).to receive(:feedback)
        .with('No assistant message to quote.', type: :warn)
      expect(chat).not_to receive(:edit_text)
      expect(chat.handle_input('/compose -r')).to eq :next
    end
  end

  describe '/vim' do
    it 'returns :next with warning when no message exists' do
      expect(chat).to receive(:feedback)
        .with(a_string_including('No message found'), type: :warn)
      expect(chat.handle_input('/vim')).to eq :next
    end

    it 'returns :next and inserts last message into vim' do
      chat.messages << OllamaChat::Message.new(
        role: 'user', content: 'vim content'
      )
      expect(chat).to receive(:vim).with(nil)
        .and_return(double('vim', insert: true))
      expect(chat.handle_input('/vim')).to eq :next
    end

    it 'passes servername to vim' do
      chat.messages << OllamaChat::Message.new(
        role: 'user', content: 'vim content'
      )
      expect(chat).to receive(:vim).with('MY_SERVER')
        .and_return(double('vim', insert: true))
      expect(chat.handle_input('/vim MY_SERVER')).to eq :next
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
    it 'returns :next when filtering help with a pattern' do
      expect(chat).to receive(:display_chat_help)
        .with(instance_of(Regexp))
      expect(chat.handle_input('/help model')).to eq :next
    end
  end
end
