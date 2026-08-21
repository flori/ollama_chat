describe OllamaChat::Tools::LookupGroup do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  connect_to_ollama_server

  let :tool do
    described_class.new
  end

  let :uuid do
    '0194a3f2-8c4d-7e1a-9b3c-abcdef012345'
  end

  before do
    chat.messages << OllamaChat::Message.new(
      role: 'user', content: 'Read the config file', group_uuid: uuid
    )
    chat.messages << OllamaChat::Message.new(
      role: 'assistant', content: 'Sure, let me read it.', group_uuid: uuid
    )
    chat.messages << OllamaChat::Message.new(
      role: 'tool', content: '{"path":"/tmp/config.yml","content":"key: value"}',
      tool_name: 'read_file', group_uuid: uuid
    )
    chat.messages << OllamaChat::Message.new(
      role: 'assistant', content: 'Here is the config.', group_uuid: uuid
    )
  end

  it 'has the expected name' do
    expect(tool.name).to eq 'lookup_group'
  end

  it 'provides a Tool instance' do
    expect(tool.tool).to be_a(Ollama::Tool)
  end

  it 'can be converted to hash' do
    expect(tool.to_hash).to be_a(Hash)
  end

  it 'returns the full messages of a matching group' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'lookup_group',
        arguments: double(group_uuid: uuid)
      )
    )

    result = tool.execute(tool_call, chat:)
    expect(result).to be_a(String)

    json = json_object(result)
    expect(json.group_uuid).to eq uuid
    expect(json.messages.size).to eq 4
    expect(json.message).to eq 'Retrieved 4 message(s) for group 0194a3f2-8c4d-7e1a-9b3c-abcdef012345.'
    expect(json.messages[0]).to eq '[user] Read the config file'
    expect(json.messages[1]).to eq '[assistant] Sure, let me read it.'
    expect(json.messages[2]).to eq '[tool (read_file)] {"path":"/tmp/config.yml","content":"key: value"}'
    expect(json.messages[3]).to eq '[assistant] Here is the config.'
  end

  it 'returns an error for a non-existent group' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'lookup_group',
        arguments: double(group_uuid: 'ffffffff-0000-0000-0000-000000000000')
      )
    )

    result = tool.execute(tool_call, chat:)
    json = json_object(result)
    expect(json.error).to eq 'OllamaChat::OllamaChatError'
    expect(json.message).to include('Group not found')
    expect(json.message).to include('ffffffff-0000-0000-0000-000000000000')
  end

  it 'returns an error when group_uuid is empty' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'lookup_group',
        arguments: double(group_uuid: '')
      )
    )

    result = tool.execute(tool_call, chat:)
    json = json_object(result)
    expect(json.error).to eq 'OllamaChat::ToolFunctionArgumentError'
    expect(json.message).to eq 'group_uuid required'
  end

  it 'matches on the suffix of the group_uuid' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'lookup_group',
        arguments: double(group_uuid: 'abcdef012345')
      )
    )

    result = tool.execute(tool_call, chat:)
    json = json_object(result)
    expect(json.group_uuid).to eq uuid
    expect(json.message).to include('Retrieved 4 message(s)')
  end
end
