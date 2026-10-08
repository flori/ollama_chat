describe OllamaChat::Tools::ReadFile do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  let :tool do
    described_class.new(chat)
  end

  connect_to_ollama_server

  it 'can have name' do
    expect(tool.name).to eq 'read_file'
  end

  it 'can have tool' do
    expect(tool.tool).to be_a Ollama::Tool
  end

  it 'can be converted to hash' do
    expect(tool.to_hash).to be_a Hash
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
          line_numbers: nil,
        )
      )
    )

    result = tool.execute(tool_call)

    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.path).to include 'example.rb'
    expect(json.content).to eq <<~EOT
      1: puts "Hello World!"
    EOT
    expect(json.message).to match(/Read .+ from/)
    expect(json.mtime).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    expect(json.line_count).to eq 1
    expect(json.checksum).to match(/\A[0-9a-f]{8}\z/)
    expect(described_class.summary_template(result:))\
      .to match(/Read .+ from/)
  end

  it 'can be executed successfully with config line_numbers false' do
    expect(tool.expose.tool_config).to receive(:line_numbers).and_return false
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'read_file',
        arguments: double(
          path: asset('example.rb'),
          start_line: nil,
          end_line: nil,
          line_numbers: nil,
        )
      )
    )

    result = tool.execute(tool_call)

    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.path).to include 'example.rb'
    expect(json.content).to eq <<~EOT
      puts "Hello World!"
    EOT
    expect(json.message).to match(/Read .+ from/)
    expect(json.mtime).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    expect(json.line_count).to be_nil
    expect(json.checksum).not_to match(/\A[0-9a-f]{8}\z/)
    expect(described_class.summary_template(result:))\
      .to match(/Read .+ from/)
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
          line_numbers: nil,
        )
      )
    )
    result = tool.execute(tool_call)
    json = json_object(result)
    expect(json.content).to eq "1: puts \"Hello World!\"\n"
    expect(json.message).to match(/Read .+ from/)
    expect(json.mtime).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    expect(json.line_count).to eq 1
    expect(json.checksum).not_to be_present
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
          line_numbers: nil,
        )
      )
    )
    result = tool.execute(tool_call)
    json = json_object(result)
    expect(json.content).to eq "1: puts \"Hello World!\"\n"
    expect(json.message).to match(/Read .+ from/)
    expect(json.mtime).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    expect(json.line_count).to eq 1
    expect(json.checksum).not_to be_present
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
          line_numbers: nil,
        )
      )
    )
    result = tool.execute(tool_call)
    json = json_object(result)
    expect(json.content).to eq ''
    expect(json.mtime).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    expect(json.line_count).to be_nil
    expect(json.checksum).not_to be_present
  end

  it 'can prefix each line with its line number' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'read_file',
        arguments: double(
          path: asset('example.rb'),
          start_line: nil,
          end_line: nil,
          line_numbers: true,
        )
      )
    )
    result = tool.execute(tool_call)
    json = json_object(result)
    expect(json.content).to include("1: puts \"Hello World!\"\n")
    expect(json.line_count).to eq 1
    expect(json.checksum).to match(/\A[0-9a-f]{8}\z/)
  end

  it 'does not prefix lines when line_numbers is false' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'read_file',
        arguments: double(
          path: asset('example.rb'),
          start_line: nil,
          end_line: nil,
          line_numbers: false,
        )
      )
    )
    result = tool.execute(tool_call)
    json = json_object(result)
    expect(json.content).not_to include("1: ")
    expect(json.mtime).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    expect(json.line_count).to be_nil
    expect(json.checksum).not_to be_present
  end

  it 'can extract range with start_line and end_line with line numbers' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'read_file',
        arguments: double(
          path: asset('example.csv'),
          start_line: 2,
          end_line: 3,
          line_numbers: true,
        )
      )
    )
    result = tool.execute(tool_call)
    json = json_object(result)
    expect(json.content).to eq(<<~EOT)
      2: John Doe,32,Software Engineer
      3: Jane Smith,28,Marketing Manager
    EOT
    expect(json.mtime).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    expect(json.line_count).to eq 5
    expect(json.checksum).not_to be_present
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
          line_numbers: nil,
        )
      )
    )

    result = tool.execute(tool_call)

    # Should return valid JSON with error
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to eq 'OllamaChat::InvalidPathError'
    expect(json.path).to eq '/etc/passwd'
    expect(json.message).to include('is not within allowed directories')
    expect(json.checksum).not_to be_present
    expect(described_class.summary_template(result:))\
      .to include('is not within allowed directories')
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
          line_numbers: nil,
        )
      )
    )

    result = tool.execute(tool_call)

    # Should return valid JSON with error
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to eq 'OllamaChat::InvalidPathError'
    expect(json.checksum).to be_nil
    expect(json.message).to match(/Failed to read file:.* does not exist/)
    expect(described_class.summary_template(result:))\
      .to match(/Failed to read file:.* does not exist/)
  end
end
