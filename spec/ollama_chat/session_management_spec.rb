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
end
