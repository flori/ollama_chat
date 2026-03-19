describe OllamaChat::Tools::GeneratePassword do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  connect_to_ollama_server

  it 'can have name' do
    expect(described_class.new.name).to eq 'generate_password'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  let :arguments do
    OpenStruct.new(
      length: nil,
      bits: nil,
      letters: nil,
      numbers: nil,
      symbols: nil,
      alphabet_type: nil,
      uppercase: nil,
      extended: nil,
    )
  end

  it 'can be executed successfully with length parameter' do
    arguments.length = 16
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'generate_password',
        arguments:
      )
    )

    result = described_class.new.execute(tool_call, chat:)

    # Should return valid JSON
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.password).to be_a(String)
    expect(json.length).to eq 16
  end

  it 'can be executed successfully with bits parameter' do
    arguments.bits = 128
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'generate_password',
        arguments:
      )
    )

    result = described_class.new.execute(tool_call, chat:)

    # Should return valid JSON
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.password).to be_a(String)
    expect(json.bits).to be >= 128
  end

  it 'can be executed successfully with base32 alphabet type' do
    arguments.alphabet_type = 'base32'
    arguments.bits = 128
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'generate_password',
        arguments:
      )
    )

    result = described_class.new.execute(tool_call, chat:)

    # Should return valid JSON
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.password).to be_a(String)
    expect(json.alphabet_type).to eq 'base32'
  end

  it 'can be executed successfully with default alphabet type' do
    arguments.length = 20
    arguments.symbols = true
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'generate_password',
        arguments:
      )
    )

    result = described_class.new.execute(tool_call, chat:)

    # Should return valid JSON
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.password).to be_a(String)
    expect(json.alphabet_type).to eq 'default'
    expect(json.symbols).to be true
  end

  it 'can handle execution errors gracefully' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'generate_password',
        arguments:
      )
    )

    # Test that it handles missing required parameters gracefully
    result = described_class.new.execute(tool_call, chat:)

    # Should return valid JSON
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to eq 'ArgumentError'
  end

  it 'can be converted t)o hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end
end
