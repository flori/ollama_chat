describe OllamaChat::Tools::DeleteFile do
  let(:chat) do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  connect_to_ollama_server

  it 'can have name' do
    expect(described_class.new.name).to eq 'delete_file'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end

  it 'can be executed successfully and create a backup' do
    file_path = './tmp/test_delete_file.txt'
    File.secure_write(file_path, 'Content to be deleted')

    tool_call = double(
      'ToolCall',
      function: double(
        name: 'delete_file',
        arguments: double(
          path: file_path
        )
      )
    )

    result = described_class.new.execute(tool_call, chat: )

    # Should return valid JSON
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.success).to eq true
    expect(json.path).to eq Pathname.new(file_path).expand_path.to_s
    expect(json.backup).not_to be_nil

    # Verify file was actually deleted
    expect(File.exist?(file_path)).to be false

    # Verify backup was created
    expect(File.exist?(json.backup)).to be true
    expect(File.read(json.backup)).to eq 'Content to be deleted'
  ensure
    # Clean up
    File.delete(file_path) if File.exist?(file_path)
  end

  it 'can handle execution errors gracefully when path is not allowed' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'delete_file',
        arguments: double(
          path: '/etc/passwd'
        )
      )
    )

    result = described_class.new.execute(tool_call, chat: )

    # Should return valid JSON with error
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to eq 'OllamaChat::InvalidPathError'
    expect(json.path).to eq '/etc/passwd'
    expect(json.message).to include('is not within allowed directories')
  end

  it 'can handle execution errors gracefully when file does not exist' do
    file_path = './tmp/non_existent_file.txt'
    File.delete(file_path) if File.exist?(file_path)

    tool_call = double(
      'ToolCall',
      function: double(
        name: 'delete_file',
        arguments: double(
          path: file_path
        )
      )
    )

    result = described_class.new.execute(tool_call, chat: )

    # Should return valid JSON with error
    expect(result).to be_a(String)
    json = json_object(result)
    # Either InvalidPathError (because check: :file fails) or Errno::ENOENT
    expect(json.success).to be_falsey
    expect(json.message).to include('Failed to delete file')
  end

  it 'can handle exceptions gracefully' do
    file_path = './tmp/test_exception_delete.txt'
    File.secure_write(file_path, 'Some content')

    tool_call = double(
      'ToolCall',
      function: double(
        name: 'delete_file',
        arguments: double(
          path: file_path
        )
      )
    )

    # Mock perform_backup to raise an error
    allow_any_instance_of(OllamaChat::Tools::DeleteFile).to receive(:perform_backup).and_raise 'Unexpected error'

    result = described_class.new.execute(tool_call, chat: )

    # Should return valid JSON with error
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to eq 'RuntimeError'
    expect(json.message).to eq 'Failed to delete file, RuntimeError: Unexpected error'
  ensure
    File.delete(file_path) if File.exist?(file_path)
  end
end
