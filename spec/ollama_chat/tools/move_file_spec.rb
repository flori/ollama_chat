describe OllamaChat::Tools::MoveFile do
  let(:chat) do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  connect_to_ollama_server

  it 'can have name' do
    expect(described_class.new.name).to eq 'move_file'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end

  it 'can move a file successfully when destination does not exist' do
    source_path = './tmp/test_move_source.txt'
    dest_path   = './tmp/test_move_dest.txt'
    content     = 'Moving this content'

    File.secure_write(source_path, content)
    File.delete(dest_path) if File.exist?(dest_path)

    tool_call = double(
      'ToolCall',
      function: double(
        name: 'move_file',
        arguments: double(
          source: source_path,
          destination: dest_path
        )
      )
    )

    result = described_class.new.execute(tool_call, chat: )

    # Should return valid JSON
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.success).to eq true
    expect(json.source).to include('test_move_source.txt')
    expect(json.destination).to include('test_move_dest.txt')

    # Verify filesystem state
    expect(File.exist?(source_path)).to be false
    expect(File.exist?(dest_path)).to be true
    expect(File.read(dest_path)).to eq content
  ensure
    File.delete(source_path) if File.exist?(source_path)
    File.delete(dest_path) if File.exist?(dest_path)
  end

  it 'fails when the destination file already exists' do
    source_path = './tmp/test_move_src_exists.txt'
    dest_path   = './tmp/test_move_dst_exists.txt'

    File.secure_write(source_path, 'Source content')
    File.secure_write(dest_path, 'Destination content')

    tool_call = double(
      'ToolCall',
      function: double(
        name: 'move_file',
        arguments: double(
          source: source_path,
          destination: dest_path
        )
      )
    )

    result = described_class.new.execute(tool_call, chat: )

    # Should return valid JSON with error
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.success).to be_falsey
    expect(json.error).to eq 'OllamaChat::InvalidPathError'
    expect(json.message).to include('does already exist')

    # Verify files are still there (no move happened)
    expect(File.exist?(source_path)).to be true
    expect(File.exist?(dest_path)).to be true
  ensure
    File.delete(source_path) if File.exist?(source_path)
    File.delete(dest_path) if File.exist?(dest_path)
  end

  it 'fails when the source file does not exist' do
    source_path = './tmp/non_existent_source.txt'
    dest_path   = './tmp/test_move_fail_src.txt'
    File.delete(source_path) if File.exist?(source_path)

    tool_call = double(
      'ToolCall',
      function: double(
        name: 'move_file',
        arguments: double(
          source: source_path,
          destination: dest_path
        )
      )
    )

    result = described_class.new.execute(tool_call, chat: )

    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.success).to be_falsey
    expect(json.error).to eq 'OllamaChat::InvalidPathError'
    expect(json.message).to include('does not exist')
  ensure
    File.delete(dest_path) if File.exist?(dest_path)
  end

  it 'fails when paths are not allowed' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'move_file',
        arguments: double(
          source: '/etc/passwd',
          destination: '/etc/passwd.bak'
        )
      )
    )

    result = described_class.new.execute(tool_call, chat: )

    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to eq 'OllamaChat::InvalidPathError'
    expect(json.message).to include('is not within allowed directories')
  end

  it 'handles general exceptions gracefully' do
    source_path = './tmp/test_exception_move.txt'
    dest_path   = './tmp/test_exception_dest.txt'
    File.secure_write(source_path, 'Some content')

    tool_call = double(
      'ToolCall',
      function: double(
        name: 'move_file',
        arguments: double(
          source: source_path,
          destination: dest_path
        )
      )
    )

    # Mock FileUtils.mv to raise error
    allow(FileUtils).to receive(:mv).and_raise 'Unexpected system error'

    result = described_class.new.execute(tool_call, chat: )

    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to eq 'RuntimeError'
    expect(json.message).to include('Unexpected system error')
  ensure
    File.delete(source_path) if File.exist?(source_path)
    File.delete(dest_path) if File.exist?(dest_path)
  end
end
