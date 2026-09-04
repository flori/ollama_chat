describe OllamaChat::Compaction do
  let :argv do
    chat_default_config
  end

  let :chat do
    OllamaChat::Chat.new(argv:).expose
  end

  connect_to_ollama_server

  let :system_template do
    chat.config.prompts.system.compaction
  end

  before do
    allow(chat).to receive(:log)
  end

  # NOTE: In production, tool results are stored with role: 'user'
  # because the Ollama API doesn't support a 'tool' role yet. They are
  # only distinguishable by having a non-nil `tool_name`.
  def msg(role, content, tool_name: nil, group_uuid: nil)
    OllamaChat::Message.new(
      role:, content:, tool_name:, group_uuid:
    )
  end

  describe '.tool_summary_line' do
    it 'delegates to the registered tool class summary_template' do
      result = { message: 'Read /etc/hosts' }.to_json
      expect(described_class.tool_summary_line('get_time', result))
        .to eq 'Read /etc/hosts'
    end

    it 'returns generic fallback for unregistered tool' do
      expect(described_class.tool_summary_line('nope', '{}'))
        .to eq 'was called.'
    end

    it 'returns the Concern fallback when summary_template rescues JSON error' do
      expect(described_class.tool_summary_line('get_time', 'not json'))
        .to eq 'was called.'
    end
  end

  describe '#format_summary_line' do
    it 'formats a user message with group_uuid' do
      m = msg('user', 'hello', group_uuid: 'abcd1234-5678-90ab-cdef-1234567890ab')
      expect(chat.format_summary_line(m)).to eq \
        '[user] (g:567890ab) hello'
    end

    it 'formats a tool result with the summary line' do
      m = msg('user', { message: 'Read /etc/hosts' }.to_json,
              tool_name: 'read_file',
              group_uuid: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeffff')
      expect(chat.format_summary_line(m)).to eq \
        '[user] (read_file) (g:eeeeffff) Read /etc/hosts'
    end

    it 'omits tool_name when nil' do
      m = msg('assistant', 'world', group_uuid: '11111111-2222-3333-4444-555555555555')
      expect(chat.format_summary_line(m)).to eq \
        '[assistant] (g:55555555) world'
    end

    it 'omits group_uuid when nil' do
      m = msg('user', 'no uuid here')
      expect(chat.format_summary_line(m)).to eq '[user] no uuid here'
    end

    it 'omits content when blank' do
      m = msg('user', '', group_uuid: '99999999-8888-7777-6666-555555555555')
      expect(chat.format_summary_line(m)).to eq \
        '[user] (g:55555555)'
    end
  end

  describe '#serialize_groups' do
    it 'rejects system messages and joins the rest' do
      messages = [
        msg('system', 'you are helpful'),
        msg('user', 'hi', group_uuid: 'aaaa1111-2222-3333-4444-555555555555'),
        msg('assistant', 'hello', group_uuid: 'aaaa1111-2222-3333-4444-555555555555'),
      ]
      expect(chat.serialize_groups(messages)).to eq \
        "[user] (g:55555555) hi\n[assistant] (g:55555555) hello"
    end

    it 'returns empty string when all are system' do
      messages = [msg('system', 'sys1'), msg('system', 'sys2')]
      expect(chat.serialize_groups(messages)).to eq ''
    end
  end

  describe '#build_tool_entries' do
    it 'returns empty array when no tool messages present' do
      messages = [
        msg('user', 'hi', group_uuid: '11111111-2222-3333-4444-555555555555'),
        msg('assistant', 'hello', group_uuid: '11111111-2222-3333-4444-555555555555'),
      ]
      expect(chat.build_tool_entries(messages)).to eq []
    end

    it 'builds Array<Hash> entries for tool messages' do
      messages = [
        msg('user', 'read the file',
            group_uuid: 'aaaaaaaa-bbbb-cccc-dddd-1234567890ab'),
        msg('user', { message: 'Read /etc/hosts' }.to_json,
            tool_name: 'read_file',
            group_uuid: 'aaaaaaaa-bbbb-cccc-dddd-1234567890ab'),
        msg('assistant', 'done',
            group_uuid: 'aaaaaaaa-bbbb-cccc-dddd-1234567890ab'),
      ]
      entries = chat.build_tool_entries(messages)
      expect(entries).to be_an Array
      expect(entries.size).to eq 1
      expect(entries[0]).to include(
        'type'    => 'tool',
        'name'    => 'read_file',
        'summary' => 'Read /etc/hosts',
        'uuid'    => '567890ab',
      )
      expect(entries[0]['time'])
        .to match(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}/)
    end

    it 'builds one entry per tool message' do
      messages = [
        msg('user', { message: 'Result A' }.to_json,
            tool_name: 'get_time',
            group_uuid: 'aaaaaaaa-bbbb-cccc-dddd-aaaaaaaaaaaa'),
        msg('user', { message: 'Result B' }.to_json,
            tool_name: 'get_time',
            group_uuid: 'bbbbbbbb-cccc-dddd-eeee-bbbbbbbbbbbb'),
      ]
      entries = chat.build_tool_entries(messages)
      expect(entries.size).to eq 2
      expect(entries[0]['uuid']).to eq 'aaaaaaaa'
      expect(entries[1]['uuid']).to eq 'bbbbbbbb'
    end

    it 'skips runtime_information messages' do
      messages = [
        msg('user', '{"runtime":"info"}',
            tool_name: 'runtime_information',
            group_uuid: 'aaaaaaaa-bbbb-cccc-dddd-cccccccccc'),
      ]
      expect(chat.build_tool_entries(messages)).to eq []
    end
  end

  describe '#call_summarizer' do
    it 'forwards the compaction system prompt to generate' do
      expect(chat).to receive(:generate) do |system:, **|
        expect(system).to eq system_template.to_s
        'The narrative.'
      end

      result = chat.call_summarizer(
        groups:      '[user] (g:aaaa) hello',
        previous_summary: nil
      )
      expect(result).to eq 'The narrative.'
    end

    it 'sends the interpolated prompt and returns the LLM response' do
      expect(chat).to receive(:generate) do |prompt:, **|
        expect(prompt).to include '[user] (g:aaaa) hello'
        'The narrative.'
      end

      result = chat.call_summarizer(
        groups:      '[user] (g:aaaa) hello',
        previous_summary: nil
      )
      expect(result).to eq 'The narrative.'
    end


    it 'includes previous_summary text in the prompt' do
      captured = nil
      expect(chat).to receive(:generate) do |prompt:, **|
        captured = prompt
        'Narrative.'
      end

      chat.call_summarizer(
        groups:      '[user] (g:aaaa) hello',
        previous_summary: 'Old summary content.'
      )
      expect(captured).to include 'Old summary content.'
    end

    it 'ends with the directive (content-first ordering)' do
      captured = nil
      expect(chat).to receive(:generate) do |prompt:, **|
        captured = prompt
        'Narrative.'
      end

      chat.call_summarizer(
        groups:      '[user] (g:aaaa) hello',
        previous_summary: nil
      )
      # last line is the directive's final sentence
      expect(captured)
        .to match(/details\s+not\s+present\s+in\s+the\s+groups\s+or\s+previous\s+summary\s+above./m)
      # directive comes after content
      expect(captured).to match(/is\s+a\s+draft/)
      expect(captured.index(/is\s+a\s+draft/))
        .to be > captured.index('[user]')
    end

    it 'raises CompactionError on empty LLM response' do
      allow(chat).to receive(:generate).and_return('')
      expect {
        chat.call_summarizer(groups: 'x', previous_summary: nil)
      }.to raise_error(OllamaChat::CompactionError, /empty response/)
    end
  end

  describe '#assemble_summary' do
    it 'returns [String, Array] with JSONL tool entries' do
      entries = [
        { 'type' => 'tool', 'name' => 'read_file',
          'summary' => 'Read file', 'uuid' => 'aaaa', 'time' => nil },
        { 'type' => 'tool', 'name' => 'run_tests',
          'summary' => 'Ran tests', 'uuid' => 'bbbb', 'time' => nil },
      ]
      content, tools = chat.assemble_summary('We did stuff.', entries)
      expect(content).to start_with 'We did stuff.'
      expect(content).to include 'tool_calls:'
      expect(content).to include '"uuid":"aaaa"'
      expect(content).to include '"uuid":"bbbb"'
      expect(content).to end_with "with the group UUID in parentheses.\n"
      expect(tools).to eq entries
    end

    it 'includes empty tool_calls section when no entries' do
      content, tools = chat.assemble_summary('Just narrative.', [])
      expect(content).to start_with 'Just narrative.'
      expect(content).to include 'tool_calls:'
      expect(content).to end_with "with the group UUID in parentheses.\n"
      expect(tools).to eq []
    end

    it 'merges old and new tool entries' do
      old = [{ 'type' => 'tool', 'name' => 'get_time',
               'summary' => 'Old A', 'uuid' => 'cccc', 'time' => nil }]
      new = [{ 'type' => 'tool', 'name' => 'get_time',
               'summary' => 'New B', 'uuid' => 'dddd', 'time' => nil }]
      content, tools = chat.assemble_summary('Narrative.', new, old)
      expect(tools.size).to eq 2
      expect(tools[0]['uuid']).to eq 'cccc'
      expect(tools[1]['uuid']).to eq 'dddd'
      expect(content).to include '"uuid":"cccc"'
      expect(content).to include '"uuid":"dddd"'
    end
  end

  describe '#summarize_for_compaction' do
    it 'returns [String, Array] with narrative and tool entries' do
      messages = [
        msg('user', 'read the file',
            group_uuid: 'aaaaaaaa-bbbb-cccc-dddd-1234567890ab'),
        msg('user', { message: 'Read /etc/hosts' }.to_json,
            tool_name: 'read_file',
            group_uuid: 'aaaaaaaa-bbbb-cccc-dddd-1234567890ab'),
        msg('assistant', 'Done.',
            group_uuid: 'aaaaaaaa-bbbb-cccc-dddd-1234567890ab'),
      ]

      expect(chat).to receive(:generate) do |system:, prompt:, **|
        'Read the hosts file.'
      end

      content, tools = chat.summarize_for_compaction(
        messages:, previous_summary: nil
      )

      expect(content).to include 'Read the hosts file.'
      expect(content).to include '"name":"read_file"'
      expect(content).to include 'lookup_group'
      expect(tools.size).to eq 1
      expect(tools[0]['name']).to eq 'read_file'
    end

    it 'reads tool_calls from attribute on re-compaction' do
      messages = [
        msg('user', { message: 'Result B' }.to_json,
            tool_name: 'get_time',
            group_uuid: 'bbbbbbbb-cccc-dddd-eeee-bbbbbbbbbbbb'),
      ]

      old_entries = [{ 'type' => 'tool', 'name' => 'get_time',
                       'summary' => 'Old A', 'uuid' => 'aaaa',
                       'time' => nil }]
      prev = OllamaChat::Message.new(
        role: 'tool', tool_name: 'summary',
        content: 'We did old stuff.',
        tool_calls: old_entries,
      )

      captured_previous = nil
      expect(chat).to receive(:generate) do |prompt:, **|
        captured_previous =
          prompt[%r{previous_summary:\n(.*?)\n\nconversation:}m, 1]
        'New narrative.'
      end

      _content, tools = chat.summarize_for_compaction(
        messages:, previous_summary: prev
      )

      expect(captured_previous).to include 'We did old stuff.'
      expect(captured_previous).not_to include 'Old A'
      expect(tools.size).to eq 2
      expect(tools[0]['uuid']).to eq 'aaaa'
      expect(tools[1]['uuid']).to eq 'bbbbbbbb'
    end
  end

  describe '#compact_with_retry' do
    it 'returns false when compact! raises and user declines retry' do
      allow(chat.messages).to receive(:compact!)
        .and_raise(OllamaChat::CompactionError, 'empty response')
      allow(chat).to receive(:confirm?).and_return(false)
      expect(chat).to receive(:current_context_length).and_return 4096

      expect(STDERR).to receive(:puts).with(/Compaction failed: empty response/)

      expect(chat.compact_with_retry).to be false
    end

    it 'reports and returns true on success' do
      result = OllamaChat::Compaction::Result.new(
        context_before: '100.0 KT of 262.1 KT (38.2%)',
        context_after:  '50.0 KT of 262.1 KT (19.1%)',
        candidates:     12,
        candidate_size: '45.2 KB / 13.0 KT',
        summary_size:   '2.1 KB / 600 T',
        stored_total:   '120.5 KB / 35.0 KT',
      )
      allow(chat.messages).to receive(:compact!).and_return(result)

      expect(STDOUT).to receive(:puts)
        .with(/Summarized:\s+12 messages/)

      expect(chat.compact_with_retry).to be true
    end

    it 'prints nothing-to-compact when compact! returns nil' do
      allow(chat.messages).to receive(:compact!).and_return(nil)

      expect(STDOUT).to receive(:puts).with('Nothing to compact.')

      expect(chat.compact_with_retry).to be true
    end
  end
end
