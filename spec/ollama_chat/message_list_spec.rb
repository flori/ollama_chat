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

  it 'cleans messages by removing tool content' do
    list << OllamaChat::Message.new(role: 'assistant', content: 'tool call', tool_name: 'test')
    expect(list.messages.last.content).to eq 'tool call'

    list.clean_messages!

    expect(list.messages.last.content).to eq ''
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

    it 'filters messages correctly' do
      list = described_class.new(chat)
      uuid = 'filter-test'
      list << OllamaChat::Message.new(role: 'user', content: 'first', group_uuid: uuid)
      list << OllamaChat::Message.new(role: 'assistant', content: 'second', group_uuid: uuid)
      list << OllamaChat::Message.new(role: 'user', content: 'third', group_uuid: uuid)

      group = list.each_group(role: 'user').to_a.first
      expect(group.map(&:content)).to eq ['first', 'third']
    end
  end

  describe '#find_cut_point' do
    before do
      allow(chat).to receive(:think_strip).and_return double(on?: false)
    end

    def add_group(list, uuid, role, content)
      list << OllamaChat::Message.new(
        role:, content:, group_uuid: uuid
      )
    end

    it 'returns nil when there are no non-system messages' do
      expect(list.find_cut_point(start: 0, keep_recent_tokens: 100)).to be_nil
    end

    it 'returns the first non-system index when everything fits' do
      add_group(list, 'g1', 'user', 'hello')       # idx 1, 2 tok
      add_group(list, 'g1', 'assistant', 'world')  # idx 2, 2 tok
      add_group(list, 'g2', 'user', 'hi')          # idx 3, 1 tok

      expect(list.find_cut_point(start: 0, keep_recent_tokens: 10)).to eq 1
    end

    it 'cuts at the group whose addition reaches the budget' do
      add_group(list, 'g1', 'user', 'hello')       # idx 1, 2 tok
      add_group(list, 'g1', 'assistant', 'world')  # idx 2, 2 tok
      add_group(list, 'g2', 'user', 'hi')          # idx 3, 1 tok

      # budget 4: walking back → 1 < 4, 3 < 4, 5 >= 4 → cut at idx 1
      expect(list.find_cut_point(start: 0, keep_recent_tokens: 4)).to eq 1

      # budget 1: walking back → 1 >= 1 → cut at idx 3
      expect(list.find_cut_point(start: 0, keep_recent_tokens: 1)).to eq 3
    end

    it 'treats multi-message groups as a single atomic unit' do
      # Group A: 2 messages = 4 tokens
      add_group(list, 'a', 'user', 'hello')
      add_group(list, 'a', 'assistant', 'world')
      # Group B: 1 message = 2 tokens
      add_group(list, 'b', 'user', 'hi hi')

      # budget 6: 4 + 2 = 6 >= 6 → cut at group A (idx 1)
      expect(list.find_cut_point(start: 0, keep_recent_tokens: 6)).to eq 1

      # budget 2: 2 >= 2 → cut at group B (idx 3)
      expect(list.find_cut_point(start: 0, keep_recent_tokens: 2)).to eq 3

      # budget 5: 2 < 5, 6 >= 5 → cut at group A (idx 1)
      expect(list.find_cut_point(start: 0, keep_recent_tokens: 5)).to eq 1
    end

    it 'skips system messages when building groups' do
      add_group(list, 's2', 'system', 'extra system')
      add_group(list, 'g1', 'user', 'hello')

      expect(list.find_cut_point(start: 0, keep_recent_tokens: 10)).to eq 2
    end

    it 'ignores messages before start' do
      add_group(list, 'old', 'user', 'aaaaa')        # idx 1, 2 tok
      add_group(list, 'old', 'assistant', 'bbbbb')   # idx 2, 2 tok
      add_group(list, 'n1', 'user', 'hi')            # idx 3, 1 tok
      add_group(list, 'n2', 'user', 'yo')            # idx 4, 1 tok

      # start: 0 includes old group (4 tok):
      #   budget 3: walk back → n2:1<3, n1:2<3, old:6>=3 → cut at 1
      expect(list.find_cut_point(start: 0, keep_recent_tokens: 3)).to eq 1

      # start: 3 excludes old group: only n1(1)+n2(1)=2 in window
      #   budget 3: walk back → n2:1<3, n1:2<3 → no-op at 3
      expect(list.find_cut_point(start: 3, keep_recent_tokens: 3)).to eq 3
    end
  end

  describe '#find_summary' do
    it 'returns nil when no summary exists' do
      expect(list.find_summary).to be_nil
    end

    it 'returns the summary message when present' do
      summary = OllamaChat::Message.new(
        role: 'tool', tool_name: 'summary',
        content: '<summary>test</summary>', group_uuid: 's1'
      )
      list << OllamaChat::Message.new(
        role: 'user', content: 'hello', group_uuid: 'g1'
      )
      list << summary

      expect(list.find_summary).to be summary
    end
  end

  describe '#compact!' do
    before do
      allow(chat).to receive(:think_strip).and_return double(on?: false)
      allow(chat).to receive(:current_context_length).and_return 100
      allow(chat).to receive(:compact_ratio_tokens)
        .with(:keep_recent, 100).and_return 5
      allow(chat).to receive(:context_usage)
        .and_return '10.0 T of 100 T (10.0%)'
      allow(chat).to receive(:conversation_length)
        .and_return '1.0 KB / 0.3 KT'
    end

    it 'returns nil when there are no non-system groups' do
      expect(list.compact!).to be_nil
      expect(list.size).to eq 1
    end

    it 'returns self unchanged when only one group exists' do
      list << OllamaChat::Message.new(
        role: 'user', content: 'hello', group_uuid: 'g1'
      )
      expect(list.compact!).to be_nil
      expect(list.size).to eq 2
    end

    it 'inserts a summary message and preserves old messages' do
      # g1: 1+1=2 tok, g2: 2+2=4 tok, g3: 1 tok → total 7
      # budget 5: walk back → 1<5, 5>=5 → cut at g2.start=3
      list << OllamaChat::Message.new(
        role: 'user', content: 'a', group_uuid: 'g1'
      )
      list << OllamaChat::Message.new(
        role: 'assistant', content: 'b', group_uuid: 'g1'
      )
      list << OllamaChat::Message.new(
        role: 'user', content: 'hello', group_uuid: 'g2'
      )
      list << OllamaChat::Message.new(
        role: 'assistant', content: 'world', group_uuid: 'g2'
      )
      list << OllamaChat::Message.new(
        role: 'user', content: 'hi', group_uuid: 'g3'
      )

      expect(chat).to receive(:log).with(:info, /Compaction:/, kind_of(Hash)).at_least(:once)

      expect(chat).to receive(:summarize_for_compaction).with(
        hash_including(previous_summary: nil)
      ).and_return(['narrative', []])

      before = list.size
      list.compact!

      expect(list.size).to eq before + 1
      summary = list.messages.find { _1.tool_name == 'summary' }
      expect(summary).not_to be_nil
      expect(summary.role).to eq 'tool'
      expect(summary.content).to eq 'narrative'
    end

    it 'passes existing summary as previous_summary on re-compaction' do
      old_summary = OllamaChat::Message.new(
        role: 'tool', tool_name: 'summary',
        content:  'old',
        group_uuid: 's1'
      )
      list << old_summary
      list << OllamaChat::Message.new(
        role: 'user', content: 'a', group_uuid: 'g1'
      )
      list << OllamaChat::Message.new(
        role: 'assistant', content: 'b', group_uuid: 'g1'
      )
      list << OllamaChat::Message.new(
        role: 'user', content: 'hello', group_uuid: 'g2'
      )
      list << OllamaChat::Message.new(
        role: 'assistant', content: 'world', group_uuid: 'g2'
      )
      list << OllamaChat::Message.new(
        role: 'user', content: 'hi', group_uuid: 'g3'
      )

      expect(chat).to receive(:log).with(:info, /Compaction:/, kind_of(Hash)).at_least(:once)

      expect(chat).to receive(:summarize_for_compaction).with(
        hash_including(previous_summary: old_summary)
      ).and_return(['new', []])

      before = list.size
      list.compact!

      expect(list.size).to eq before
      summaries = list.messages.select { _1.tool_name == 'summary' }
      expect(summaries.size).to eq 1
      expect(summaries.first.content).to eq 'new'
    end

    it 'calls sync' do
      list << OllamaChat::Message.new(
        role: 'user', content: 'a', group_uuid: 'g1'
      )
      list << OllamaChat::Message.new(
        role: 'assistant', content: 'b', group_uuid: 'g1'
      )
      list << OllamaChat::Message.new(
        role: 'user', content: 'hello', group_uuid: 'g2'
      )
      list << OllamaChat::Message.new(
        role: 'assistant', content: 'world', group_uuid: 'g2'
      )
      list << OllamaChat::Message.new(
        role: 'user', content: 'hi', group_uuid: 'g3'
      )
      allow(chat).to receive(:summarize_for_compaction)
        .and_return(['x', []])

      expect(chat).to receive(:log).with(:info, /Compaction:/, kind_of(Hash)).at_least(:once)

      expect(list).to receive(:sync)
      list.compact!
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
      expect(chat).to receive(:prompt).with(nil, context: 'system')
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
    expect(chat).to receive(:prompt).with('test_prompt', context: 'system').and_return('test prompt')
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
    expect(chat).to receive(:prompt).with('first_prompt', context: 'system').and_return('first prompt')
    expect(chat).to receive(:runtime_info).and_return(double(on?: true)).at_least(:once)
    expect(chat).to receive(:static_runtime_information).at_least(:once)
    expect(list.messages.count { _1.role == 'system' }).to eq 0
    list.set_system_prompt('first_prompt')
    expect(list.system).to eq('first prompt')
    expect(list.messages.count { _1.role == 'system' }).to eq 1
    #
    expect(chat).to receive(:prompt).with('new_prompt', context: 'system').and_return('new prompt')
    list.set_system_prompt('new_prompt')
    expect(list.system).to eq('new prompt')
    expect(list.messages.count { _1.role == 'system' }).to eq 1
    expect(list.messages.first.role).to eq('system')
    expect(list.messages.first.content).to eq('new prompt')
  end

  context 'with uuid groups' do
    let :group_1 do
      OllamaChat::UUIDV7.generate
    end

    let :group_2 do
      OllamaChat::UUIDV7.generate
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
