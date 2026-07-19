describe OllamaChat::Tools::WriteFile do
  let(:chat) do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  connect_to_ollama_server

  it 'can have name' do
    expect(described_class.new.name).to eq 'write_file'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end

  let(:test_write_file) { "./tmp/test_write_file_#{Tins::Token.new(bits: 64)}.txt" }

  it 'can be executed successfully with overwrite mode' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'write_file',
        arguments: double(
          path: test_write_file,
          content: 'Hello, World!',
          mode: 'overwrite'
        )
      )
    )

    result = described_class.new.execute(tool_call, chat:)

    # Should return valid JSON
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.success).to eq true
    expect(json.path).to include(File.basename(test_write_file))
    expect(json.message).to include('Wrote 13.0 B (4.0 T) to file')

    # Verify file was actually written
    expect(File.exist?(test_write_file)).to be true
    expect(File.read(test_write_file)).to eq 'Hello, World!'
  ensure
    # Clean up
    File.delete(test_write_file) if File.exist?(test_write_file)
  end

  it 'can be executed successfully with append mode' do
    # First write some initial content
    initial_content = 'Initial content\n'
    File.secure_write(test_write_file, initial_content)

    tool_call = double(
      'ToolCall',
      function: double(
        name: 'write_file',
        arguments: double(
          path: test_write_file,
          content: 'Appended content\n',
          mode: 'append'
        )
      )
    )

    result = described_class.new.execute(tool_call, chat:)

    # Should return valid JSON
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.success).to be true
    expect(json.path).to include(File.basename(test_write_file))
    expect(json.message).to include('Wrote 18.0 B (6.0 T) to file')

    # Verify file was actually appended
    expect(File.exist?(test_write_file)).to be true
    content = File.read(test_write_file)
    expect(content).to include('Initial content')
    expect(content).to include('Appended content')
  ensure
    # Clean up
    File.delete(test_write_file) if File.exist?(test_write_file)
  end

  it 'can handle execution errors gracefully when path is not allowed' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'write_file',
        arguments: double(
          path: '/etc/passwd',
          content: 'malicious content',
          mode: 'overwrite'
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

  it 'can handle execution errors gracefully when mode is invalid' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'write_file',
        arguments: double(
          path: 'tmp/foo',
          content: 'malicious content',
          mode: 'foobar'
        )
      )
    )

    result = described_class.new.execute(tool_call, chat:)

    # Should return valid JSON with error
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to eq 'ArgumentError'
    expect(json.message).to include('Invalid mode')
  end

  it 'can handle exceptions gracefully' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'write_file',
        arguments: double(
          path: 'tmp/fake.txt',
          content: 'some content',
          mode: 'overwrite'
        )
      )
    )

    expect(File).to receive(:secure_write).and_raise 'some error'
    result = described_class.new.execute(tool_call, chat:)

    # Should return valid JSON with error
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to eq 'RuntimeError'
    expect(json.path).to be_nil
    expect(json.message).to eq 'Failed to write to file: some error'
  end
end
