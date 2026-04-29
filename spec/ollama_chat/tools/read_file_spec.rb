describe OllamaChat::Tools::ReadFile do
  let(:chat) do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  connect_to_ollama_server

  it 'can have name' do
    expect(described_class.new.name).to eq 'read_file'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end

  it 'can be executed successfully' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'read_file',
        arguments: double(
          path: asset('example.rb'),
          start_line: nil,
          end_line: nil,
        )
      )
    )

    result = described_class.new.execute(tool_call, chat:)

    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.path).to include 'example.rb'
    expect(json.content).to eq <<~EOT
      puts "Hello World!"
    EOT
  end

  it 'can extract range when start_line is provided and end_line is nil' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'read_file',
        arguments: double(
          path: asset('example.rb'),
          start_line: 1,
          end_line: nil,
        )
      )
    )
    result = described_class.new.execute(tool_call, chat:)
    json = json_object(result)
    expect(json.content).to eq "puts \"Hello World!\"\n"
  end

  it 'can extract range when start_line is nil and end_line is provided' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'read_file',
        arguments: double(
          path: asset('example.rb'),
          start_line: nil,
          end_line: 1,
        )
      )
    )
    result = described_class.new.execute(tool_call, chat:)
    json = json_object(result)
    expect(json.content).to eq "puts \"Hello World!\"\n"
  end

  it 'returns empty content when end_line is less than start_line' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'read_file',
        arguments: double(
          path: asset('example.rb'),
          start_line: 2,
          end_line: 1,
        )
      )
    )
    result = described_class.new.execute(tool_call, chat:)
    json = json_object(result)
    expect(json.content).to eq ''
  end

  it 'can handle execution errors gracefully when path is not allowed' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'read_file',
        arguments: double(
          path: '/etc/passwd',
          start_line: nil,
          end_line: nil,
        )
      )
    )

    result = described_class.new.execute(tool_call, chat:)

    # Should return valid JSON with error
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to eq 'OllamaChat::InvalidPathError'
    expect(json.path).to eq '/etc/passwd'
    expect(json.message).to include('is not within allowed directories')
  end

  it 'can handle exceptions gracefully' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'read_file',
        arguments: double(
          path: asset('not-there.txt'),
          start_line: nil,
          end_line: nil,
        )
      )
    )

    result = described_class.new.execute(tool_call, chat:)

    # Should return valid JSON with error
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to eq 'OllamaChat::InvalidPathError'
    expect(json.message).to match(/Failed to read file:.* does not exist/)
  end
end
