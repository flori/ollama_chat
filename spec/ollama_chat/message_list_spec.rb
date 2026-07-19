describe OllamaChat::MessageList do
  let :config do
    double(
      location: double(
        enabled: false,
        name: 'Berlin',
        decimal_degrees: [ 52.514127, 13.475211 ],
        units: 'SI (International System of Units)'
      ),
      prompts: double(
        location: 'You are at %{location_name} (%{location_decimal_degrees}),' \
        ' preferring %{units}'
      ),
      system_prompts: double(
        assistant?: 'You are a helpful assistant.'
      )
    )
  end

  let :chat do
    double('Chat', config:, store_messages_in_session: true, infobar_message: '')
  end

  before do
    chat.extend OllamaChat::LocationHandling
  end

  before do
    allow(chat).to receive(:kramdown_ansi_parse) do |content|
      Kramdown::ANSI.parse(content)
    end
  end

  let :list do
    described_class.new(chat).tap do |list|
      list << OllamaChat::Message.new(role: 'system', content: 'hello', thinking: 'a while')
    end
  end

  it 'can clear non system messages' do
    expect(list.size).to eq 1
    list.clear
    expect(list.size).to eq 1
    list << OllamaChat::Message.new(role: 'user', content: 'world')
    expect(list.size).to eq 2
    list.clear
    expect(list.size).to eq 1
  end

  it 'can be added to' do
    expect(list.size).to eq 1
    list << OllamaChat::Message.new(role: 'user', content: 'world')
    expect(list.size).to eq 2
  end

  it 'has a last message' do
    expect(list.last).to be_a OllamaChat::Message
  end

  describe '#find_last' do
    it 'can find last message' do
      expect(list.find_last { true }.content).to eq 'hello'
    end

    it 'can find last message with or w/o content' do
      list << OllamaChat::Message.new(role: 'assistant', content: 'yep')
      list << OllamaChat::Message.new(role: 'user', content: 'world')
      list << OllamaChat::Message.new(role: 'assistant', content: '')
      expect(list.find_last { _1.role == 'assistant' }.content).to be_empty
      expect(list.find_last(content: true) { _1.role == 'assistant' }.content).to eq 'yep'
    end
  end

  describe '#each_group' do
    it 'groups messages by group_uuid' do
      list = described_class.new(chat)
      uuid1 = 'group-1'
      uuid2 = 'group-2'

      list << OllamaChat::Message.new(role: 'user', content: 'msg 1', group_uuid: uuid1)
      list << OllamaChat::Message.new(role: 'assistant', content: 'ans 1', group_uuid: uuid1)
      list << OllamaChat::Message.new(role: 'user', content: 'msg 2', group_uuid: uuid2)
      list << OllamaChat::Message.new(role: 'assistant', content: 'ans 2', group_uuid: uuid2)
      expect(list.size).to eq 4

      groups = list.each_group.to_a
      expect(groups.size).to eq 2
      expect(groups[0].map(&:content)).to eq ['msg 1', 'ans 1']
      expect(groups[1].map(&:content)).to eq ['msg 2', 'ans 2']
    end

    it 'returns an empty collection when there are no messages' do
      list = described_class.new(chat)
      list.messages.clear
      expect(list.each_group.to_a).to be_empty
    end

    it 'handles a single message in a group' do
      list = described_class.new(chat)
      list << OllamaChat::Message.new(role: 'user', content: 'alone', group_uuid: 'single')

      groups = list.each_group.to_a
      expect(groups.size).to eq 1
      expect(groups.first.first.content).to eq 'alone'
    end

    it 'preserves relative order within groups' do
      list = described_class.new(chat)
      uuid = 'order-test'
      list << OllamaChat::Message.new(role: 'user', content: 'first', group_uuid: uuid)
      list << OllamaChat::Message.new(role: 'assistant', content: 'second', group_uuid: uuid)
      list << OllamaChat::Message.new(role: 'user', content: 'third', group_uuid: uuid)

      group = list.each_group.to_a.first
      expect(group.map(&:content)).to eq ['first', 'second', 'third']
    end
  end

  describe '.load_conversation' do
    it 'can load conversations in JSON if existing' do
      expect(list.messages.first.role).to eq  'system'
      expect(list.load_conversation(asset('conversation-nixda.json'))).to be_nil
      expect {
        list.load_conversation(asset('conversation.json'))
      }.to change { list.messages.size }.from(1).to(3)
      expect(list.messages.map(&:role)).to eq %w[ system user assistant ]
    end

    it 'can load conversations in JSONL if existing' do
      expect(list.messages.first.role).to eq  'system'
      expect(list.load_conversation(asset('conversation-nixda.jsonl'))).to be_nil
      expect {
        list.load_conversation(asset('conversation.jsonl'))
      }.to change { list.messages.size }.from(1).to(3)
      expect(list.messages.map(&:role)).to eq %w[ system user assistant ]
    end
  end

  describe '.save_conversation' do
    it 'can save conversations in JSON' do
      expect(list.save_conversation('tmp/test-conversation.json')).to eq list
    ensure
      FileUtils.rm_f 'tmp/test-conversation.json'
    end

    it 'can save conversations in JSONL' do
      expect(list.save_conversation('tmp/test-conversation.jsonl')).to eq list
    ensure
      FileUtils.rm_f 'tmp/test-conversation.jsonl'
    end

    it 'can save conversations with thinking' do
      expect(list.save_conversation('tmp/test-conversation.json')).to eq list
      expect(JSON.load(File.new('tmp/test-conversation.json'))[0]['thinking']).to eq 'a while'
    ensure
      FileUtils.rm_f 'tmp/test-conversation.json'
    end
  end

  describe "#last" do
    it "returns the last message when there are multiple messages" do
      list = described_class.new(chat)
      list << OllamaChat::Message.new(role: 'system', content: 'hello')
      list << OllamaChat::Message.new(role: 'user', content: 'First message')
      list << OllamaChat::Message.new(role: 'assistant', content: 'Second message')

      expect(list.last.content).to eq('Second message')
    end

    it "returns the last message when there is only one message" do
      list = described_class.new(chat)
      list << OllamaChat::Message.new(role: 'system', content: 'hello')

      expect(list.last.content).to eq('hello')
    end

    it "returns nil when there are no messages" do
      list = described_class.new(chat)

      expect(list.last).to be_nil
    end
  end

  describe '#show_last' do
    it 'shows nothing when there are no messages' do
      empty_list = described_class.new(chat)
      expect(chat).to receive(:think_loud).and_return(double(on?: false)).at_least(:once)
      expect { empty_list.show_last }.not_to raise_error
      expect(empty_list.show_last).to be nil
    end

    it 'shows nothing when the last message is by the assistant' do
      list = described_class.new(chat)
      expect(chat).to receive(:think_loud).and_return(double(on?: false)).at_least(:once)
      expect(chat).to receive(:markdown).and_return(double(on?: false))
      list << OllamaChat::Message.new(role: 'assistant', content: 'hello')
      expect(STDOUT).to receive(:puts).
        with("📨 \e[1m\e[38;5;111massistant\e[0m\e[0m:\nhello\n")
      expect(list.show_last).to be_a described_class
    end

    it 'shows nothing when the last message is by the user' do
      list = described_class.new(chat)
      list << OllamaChat::Message.new(role: 'user', content: 'world')
      expect(chat).to receive(:think_loud).and_return(double(on?: false)).at_least(:once)
      expect { list.show_last }.not_to raise_error
      expect(list.show_last).to be nil
    end

    it "shows last N messages when N is larger than available messages" do
      expect(chat).to receive(:think_loud).and_return(double(on?: false))
      expect(chat).to receive(:markdown).and_return(double(on?: false))
      list = described_class.new(chat)
      list << OllamaChat::Message.new(role: 'system', content: 'hello')
      list << OllamaChat::Message.new(role: 'user', content: 'First message')
      list << OllamaChat::Message.new(role: 'assistant', content: 'Second message')

      expect(chat).to receive(:markdown).and_return(double(on?: true)).at_least(:once)
      expect(STDOUT).to receive(:puts).with(/Second message/)
      expect(list.show_last(23)).to eq(list)
    end
  end

  context 'without pager' do
    before do
      expect(list).to receive(:determine_pager_command).and_return nil
    end

    it 'can show last message' do
      expect(chat).to receive(:markdown).
        and_return(double(on?: true)).at_least(:once)
      expect(chat).to receive(:think_loud).and_return(double(on?: false)).at_least(:once)
      expect(STDOUT).to receive(:puts).
        with("📨 \e[1m\e[38;5;213msystem\e[0m\e[0m:\nhello\n")
      list.show_last
    end

    it 'can list conversations without thinking' do
      expect(chat).to receive(:markdown).
        and_return(double(on?: true)).at_least(:once)
      expect(chat).to receive(:think_loud).and_return(double(on?: false)).at_least(:once)
      list << OllamaChat::Message.new(role: 'user', content: 'world')
      expect(STDOUT).to receive(:puts).
        with(
          "📨 \e[1m\e[38;5;213msystem\e[0m\e[0m:\nhello\n" \
          "📨 \e[1m\e[38;5;172muser\e[0m\e[0m:\nworld\n"
        )
      list.list_conversation
    end

    it 'can list conversations with thinking' do
      expect(chat).to receive(:system_prompt)
      expect(chat).to receive(:runtime_info).and_return(double(on?: true))
      expect(chat).to receive(:static_runtime_information)
      expect(chat).to receive(:default_persona_profile)
      expect(chat).to receive(:markdown).
        and_return(double(on?: true)).at_least(:once)
      expect(chat).to receive(:think_loud).and_return(double(on?: true)).at_least(:once)
      expect(STDOUT).to receive(:puts).
        with(
          "📨 \e[1m\e[38;5;213msystem\e[0m\e[0m:\n" \
          "💭\nI need to say something nice…\n\n💬\nhello\n" \
          "📨 \e[1m\e[38;5;172muser\e[0m\e[0m:\nworld\n"
        )
      list.set_system_prompt nil
      list << OllamaChat::Message.new(
        role: 'system', content: 'hello',
        thinking: 'I need to say something nice…'
      )
      list << OllamaChat::Message.new(role: 'user', content: 'world')
      list.list_conversation
    end
  end

  context 'with pager' do
    before do
      expect(list).to receive(:determine_pager_command).and_return 'true'
      expect(Tins::Terminal).to receive(:lines).and_return 1
    end

    it 'can list conversations' do
      skip 'no tty' unless STDOUT.tty?
      expect(chat).to receive(:markdown).
        and_return(double(on?: true)).at_least(:once)
      expect(chat).to receive(:think_loud).and_return(double(on?: false)).at_least(:once)
      list << OllamaChat::Message.new(role: 'user', content: 'world')
      list.list_conversation
    end
  end

  it 'can show_system_prompt' do
    expect(list).to receive(:system).and_return 'test **prompt**'
    expect(list.show_system_prompt).to eq list
  end

  it 'can set_system_prompt if unset' do
    list.messages.clear
    expect(list.messages.count { _1.role == 'system' }).to eq 0
    expect(chat).to receive(:default_persona_profile).and_return(nil)
    expect(chat).to receive(:system_prompt).and_return('test prompt')
    expect(chat).to receive(:runtime_info).and_return(double(on?: true))
    expect(chat).to receive(:static_runtime_information)
    expect {
      expect(list.set_system_prompt('test_prompt')).to eq list
    }.to change { list.system }.from(nil).to('test prompt')
    expect(list.messages.count { _1.role == 'system' }).to eq 1
    expect(list.messages.find { _1.role == 'system' }.group_uuid).to be_present
  end

  it 'can set_system_prompt if already set' do
    expect(chat).to receive(:default_persona_profile).and_return(nil).at_least(:once)
    list.messages.clear
    expect(chat).to receive(:system_prompt).and_return('first prompt')
    expect(chat).to receive(:runtime_info).and_return(double(on?: true)).at_least(:once)
    expect(chat).to receive(:static_runtime_information).at_least(:once)
    expect(list.messages.count { _1.role == 'system' }).to eq 0
    list.set_system_prompt('first_prompt')
    expect(list.system).to eq('first prompt')
    expect(list.messages.count { _1.role == 'system' }).to eq 1
    #
    expect(chat).to receive(:system_prompt).and_return('new prompt')
    list.set_system_prompt('new_prompt')
    expect(list.system).to eq('new prompt')
    expect(list.messages.count { _1.role == 'system' }).to eq 1
    expect(list.messages.first.role).to eq('system')
    expect(list.messages.first.content).to eq('new prompt')
  end

  context 'with uuid groups' do
    let :group_1 do
      SecureRandom.uuid_v7
    end

    let :group_2 do
      SecureRandom.uuid_v7
    end

    it 'can drop n conversations exhanges' do
      expect(list.size).to eq 1
      expect(list.drop(1)).to eq 0
      expect(list.size).to eq 1
      list << OllamaChat::Message.new(role: 'user', content: 'world', group_uuid: group_1)
      expect(list.size).to eq 2
      list << OllamaChat::Message.new(role: 'assistant', content: 'hi', group_uuid: group_1)
      expect(list.size).to eq 3
      expect(list.drop(1)).to eq 1
      expect(list.size).to eq 1
      expect(list.drop(1)).to eq 0
      expect(list.size).to eq 1
      expect(list.drop(1)).to eq 0
      expect(list.size).to eq 1
    end

    it 'drops the last user message when there is no assistant response' do
      expect(list.size).to eq 1
      list << OllamaChat::Message.new(role: 'user', content: 'hello', group_uuid: group_1)
      list << OllamaChat::Message.new(role: 'assistant', content: 'hi', group_uuid: group_1)
      list << OllamaChat::Message.new(role: 'user', content: 'world', group_uuid: group_2)
      expect(list.size).to eq 4
      expect(list.drop(1)).to eq 1
      expect(list.size).to eq 3
      expect(list.drop(1)).to eq 1
      expect(list.size).to eq 1
    end
  end

  it 'can be converted int an OllamaChat::Message array' do
    list << OllamaChat::Message.new(role: 'user', content: 'world')
    expect(list.to_ary.map(&:as_json)).to eq [
      OllamaChat::Message.new(role: 'system', content: 'hello', thinking: 'a while').as_json,
      OllamaChat::Message.new(role: 'user', content: 'world').as_json,
    ]
  end

  it 'can display messages with images' do
    expect(list.message_type([])).to eq ?📨
  end

  it 'can display messages without images' do
    expect(list.message_type(%w[ image ])).to eq ?📸
  end
end
