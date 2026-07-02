describe OllamaChat::Tools::GetTime do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  connect_to_ollama_server

  it 'can have name' do
    expect(described_class.new.name).to eq 'get_time'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end

  it 'can be executed successfully' do
    Time.dummy = '2011-11-11T11:11:11+0200'
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'get_time',
        arguments: double()
      )
    )

    result = described_class.new.execute(tool_call, chat:)

    json = json_object(result)

    expect(json.time).to match(
      /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}\z/
    )
    expect(json.weekday).to be_present
    expect(json.message).to eq 'Good morning! It is currently 11:11 on Friday.'
  ensure
    Time.dummy = nil
  end
end
