describe OllamaChat::SessionManagement do
  let :chat do
    OllamaChat::Chat.new(argv: []).expose
  end

  connect_to_ollama_server

  describe '#repair_group_uuids' do
    it 'assigns a unique UUID to the first system message if missing' do
      msg = OllamaChat::Message.new(role: 'system', content: 'sys')
      msg.group_uuid = nil # Ensure it is missing
      chat.messages << msg

      chat.repair_group_uuids
      expect(msg.group_uuid).not_to be_nil
    end

    it 'groups legacy User -> Assistant exchanges and assigns a shared UUID' do
      u1 = OllamaChat::Message.new(role: 'user', content: 'hello')
      a1 = OllamaChat::Message.new(role: 'assistant', content: 'hi')
      u1.group_uuid = nil
      a1.group_uuid = nil

      chat.messages << u1 << a1

      chat.repair_group_uuids
      expect(u1.group_uuid).to eq(a1.group_uuid)
      expect(u1.group_uuid).not_to be_nil
    end

    it 'swaps [RuntimeInfo, User] to [User, RuntimeInfo] and groups them' do
      # Simulation of legacy order: Runtime Info came BEFORE user
      ri = OllamaChat::Message.new(role: 'user', tool_name: 'runtime_information', content: 'info')
      u1 = OllamaChat::Message.new(role: 'user', content: 'hello')
      a1 = OllamaChat::Message.new(role: 'assistant', content: 'hi')

      ri.group_uuid = nil
      u1.group_uuid = nil
      a1.group_uuid = nil

      chat.messages << ri << u1 << a1

      chat.repair_group_uuids

      # Verify Order: User should now be before RuntimeInfo
      msgs = chat.messages.messages
      expect(msgs[0].role).to eq('user')
      expect(msgs[0].content).to eq('hello')
      expect(msgs[1].tool_name).to eq('runtime_information')

      # Verify Grouping: User and the moved RuntimeInfo should share UUID
      expect(msgs[0].group_uuid).to eq(msgs[1].group_uuid)
      expect(msgs[1].group_uuid).to eq(a1.group_uuid)
    end

    it 'propagates the group UUID to subsequent tool messages' do
      u1 = OllamaChat::Message.new(role: 'user', content: 'hello')
      t1 = OllamaChat::Message.new(role: 'user', tool_name: 'some_tool', content: 'result')
      a1 = OllamaChat::Message.new(role: 'assistant', content: 'hi')

      u1.group_uuid = nil
      t1.group_uuid = nil
      a1.group_uuid = nil

      chat.messages << u1 << t1 << a1

      chat.repair_group_uuids
      expect(u1.group_uuid).to eq(t1.group_uuid)
      expect(t1.group_uuid).to eq(a1.group_uuid)
    end

    it 'assigns unique UUIDs to orphaned messages' do
      # A message that isn't preceded by a user anchor (e.g. an assistant msg at start)
      orphan = OllamaChat::Message.new(role: 'assistant', content: 'ghost')
      orphan.group_uuid = nil

      chat.messages << orphan

      chat.repair_group_uuids
      expect(orphan.group_uuid).not_to be_nil
    end

    it 'does not override existing group UUIDs' do
      fixed_id = SecureRandom.uuid_v7
      u1 = OllamaChat::Message.new(role: 'user', content: 'hello', group_uuid: fixed_id)
      a1 = OllamaChat::Message.new(role: 'assistant', content: 'hi', group_uuid: fixed_id)

      chat.messages << u1 << a1

      chat.repair_group_uuids
      expect(u1.group_uuid).to eq(fixed_id)
    end
  end

  describe '#previous_session' do
    it 'returns nil if no previous session ID is set' do
      expect(chat.previous_session).to be_nil
    end

    it 'returns the previous session if it exists and is unlocked' do
      prev = chat.new_session.tap { |s| s.name = 'prev_test'; s.save }
      chat.instance_variable_set(:@previous_session_id, prev.id)
      expect(chat.previous_session).to eq(prev)
    end

    it 'returns nil if the previous session is locked' do
      prev = chat.new_session.tap { |s| s.name = 'locked_test'; s.save }
      prev.lock?
      chat.instance_variable_set(:@previous_session_id, prev.id)
      expect(chat.previous_session).to be_nil
    end
  end

  describe '#choose_session' do
    it 'finds session by exact ID' do
      s = chat.new_session.tap { |s| s.name = 'id_test'; s.save }
      expect(chat.choose_session(s.id)).to eq(s)
    end

    it 'finds session by exact name' do
      s = chat.new_session.tap { |s| s.name = 'name_test'; s.save }
      expect(chat.choose_session('name_test')).to eq(s)
    end

    it 'excludes session when except_id is provided' do
      s1 = chat.new_session.tap { |s| s.name = 'exc1'; s.save }
      s2 = chat.new_session.tap { |s| s.name = 'exc2'; s.save }
      expect(chat.choose_session(s1.id, except_id: s1.id)).to be_nil
      expect(chat.choose_session(s2.id, except_id: s1.id)).to eq(s2)
    end
  end

  describe '#store_messages_in_session' do
    it 'serializes messages to JSONL and updates session' do
      chat.messages << OllamaChat::Message.new(role: 'user', content: 'test_msg')
      expect { chat.store_messages_in_session }.not_to raise_error
      expect(chat.session.messages.to_s).to include('test_msg')
    end
  end

  describe '#store_links_in_session' do
    it 'serializes links to JSONL and updates session' do
      links = ['http://a.com', 'http://b.com']
      expect { chat.store_links_in_session(links) }.not_to raise_error
      expect(chat.session.links).to include('a.com')
    end
  end

  describe '#load_links_from_session' do
    it 'deserializes links from session' do
      chat.store_links_in_session(['http://x.com', 'http://y.com'])
      loaded = chat.load_links_from_session
      expect(loaded.to_a).to eq(['http://x.com', 'http://y.com'])
    end
  end

  describe '#new_session' do
    it 'creates a new session with defaults' do
      new_s = chat.new_session
      expect(new_s).to be_a(OllamaChat::Database::Models::Session)
    end
  end

  describe '#preferred_session' do
    it 'returns the last updated session for the current directory' do
      allow(Dir).to receive(:pwd).and_return('/test_dir')
      _s1 = chat.new_session.tap { |s| s.name = "pref1_#{rand(1000)}"; s.working_directory = '/test_dir'; s.save }
      sleep(0.01)
      s2 = chat.new_session.tap { |s| s.name = "pref2_#{rand(1000)}"; s.working_directory = '/test_dir'; s.save }
      expect(chat.preferred_session).to eq(s2)
    end

    it 'returns a new session if none exist for the directory' do
      allow(Dir).to receive(:pwd).and_return('/empty_dir')
      expect(chat.preferred_session).to be_a(OllamaChat::Database::Models::Session)
    end
  end

  describe '#session_close' do
    it 'stores messages, syncs links, saves history, and unlocks session' do
      expect(chat).to receive(:store_messages_in_session)
      expect(chat).to receive(:links).and_return(double(sync: nil))
      expect(chat).to receive(:save_history)
      expect(chat.session).to receive(:unlock)
      chat.session_close
    end
  end

  describe '#session_apply' do
    it 'updates working directory and initializes history' do
      allow(Dir).to receive(:pwd).and_return('/curr')
      expect(chat.session).to receive(:update).with(working_directory: '/curr')
      expect(chat).to receive(:init_history)
      expect(chat.session_apply).to eq(chat.session)
    end
  end

  describe '#derive_session_name' do
    it 'generates and cleans up a title based on message content' do
      chat.messages << OllamaChat::Message.new(role: 'user', content: 'Hello world')
      expect(chat).to receive(:prompt).and_return(double(to_s: 'prompt'))
      expect(chat).to receive(:generate).and_return('  Generated Title  ')
      result = chat.derive_session_name
      expect(result).to eq('Generated Title')
    end
  end
  describe '#duplicate_session' do
    it 'creates a copy of the current session' do
      expect(chat).to receive(:determine_valid_new_name_for_session).and_return('dup_test')
      expect(chat).to receive(:confirm?).and_return(false)
      expect { chat.duplicate_session }.to change { OllamaChat::Database::Models::Session.count }.by(1)
      expect(OllamaChat::Database::Models::Session.where(name: 'dup_test').first).not_to be_nil
    end
  end

  describe '#delete_session' do
    it 'prompts for a new session and deletes the current one' do
      new_s = chat.new_session.tap { |s| s.name = 'new_after_delete'; s.save }
      expect(chat).to receive(:choose_session).and_return(new_s)
      expect(chat).to receive(:confirm?).and_return(true).at_least(:once)
      expect(chat).to receive(:change_session).with(new_s.id)
      expect { chat.delete_session }.to change { OllamaChat::Database::Models::Session.count }.by(-1)
    end
  end

  describe '#rename_session' do
    it 'updates the session name when provided a valid new name' do
      expect(chat).to receive(:ask?).and_return('renamed_session')
      expect(chat).to receive(:switch_history).and_yield
      expect { chat.rename_session }.to change { chat.session.name }.to('renamed_session')
    end
  end

  describe '#list_sessions' do
    it 'outputs a table of sessions without raising errors' do
      chat.new_session.tap { |s| s.name = 'list_test'; s.save }
      expect(STDOUT).to receive(:puts).with(/New Session/)
      expect { chat.list_sessions }.not_to raise_error
    end
  end

  describe '#show_session' do
    it 'displays session information including name and ID' do
      output = StringIO.new
      expect { chat.show_session(output: output) }.not_to raise_error
      expect(output.string).to include(chat.session.name)
      expect(output.string).to include(chat.session.id.to_s)
    end
  end

  describe '#determine_valid_new_name_for_session' do
    it 'returns the name immediately if unique' do
      expect(chat).to receive(:ask?).and_return('unique_name')
      expect(chat.determine_valid_new_name_for_session('to create')).to eq('unique_name')
    end

    it 're-prompts if the name already exists' do
      chat.new_session.tap { |s| s.name = 'taken_name'; s.save }
      expect(chat).to receive(:ask?).and_return('taken_name', 'new_unique')
      expect(chat.determine_valid_new_name_for_session('to create')).to eq('new_unique')
    end

    it 'returns nil if the user provides an empty string (cancel)' do
      expect(chat).to receive(:ask?).and_return('')
      expect(chat.determine_valid_new_name_for_session('to create')).to be_nil
    end
  end

  describe '#set_new_session' do
    it 'creates, locks, and applies a new session' do
      expect(chat).to receive(:switch_history).and_yield
      expect(chat).to receive(:determine_valid_new_name_for_session).and_return('new_sess')
      expect(chat).to receive(:session_close)
      expect(chat).to receive(:session_apply)
      expect(chat).to receive(:use_model)
      expect(chat).to receive(:copy_model_options_to_session)

      expect { chat.set_new_session }.to change { OllamaChat::Database::Models::Session.count }.by(1)
      expect(chat.session.name).to eq('new_sess')
    end
  end

  describe '#setup_session' do
    it 'uses preferred_session when no options are provided' do
      chat.instance_variable_set(:@opts, {})
      expect(chat).to receive(:preferred_session).and_return(chat.session)
      expect(chat).to receive(:session_apply).and_return(chat.session)
      allow(chat.session).to receive(:lock?).and_return(true)
      expect(chat.setup_session).to eq(chat.session)
    end
  end

  describe '#summarize_session' do
    it 'summarizes messages and yields content' do
      chat.messages << OllamaChat::Message.new(role: 'user', content: 'summarize me')
      expect(chat).to receive(:prompt).and_return(double(to_s: 'prompt'))
      expect(chat).to receive(:generate).and_return('Summary content')
      expect(chat).to receive(:sender_name_displayed).at_least(:once).and_return('User')
      expect(chat).to receive(:infobar_message).and_return('')

      results = []
      chat.summarize_session { |c| results << c }
      expect(results).to include(a_string_including('Summary content'))
    end
  end

  describe '#change_session' do
    it 'switches to a different session and updates state' do
      new_s = chat.new_session.tap { |s| s.name = 'change_to_me'; s.save }
      expect(chat).to receive(:choose_session).and_return(new_s)
      expect(chat).to receive(:session_close)
      expect(chat).to receive(:repair_group_uuids)
      expect(chat).to receive(:set_current_collection)
      expect(chat).to receive(:use_model)
      expect(chat).to receive(:set_default_persona_name)
      expect(chat).to receive(:set_current_system_prompt)
      expect(chat).to receive(:session_apply)
      expect(chat).to receive(:info_session)

      chat.change_session(new_s.name)
      expect(chat.session).to eq(new_s)
    end
  end
end
