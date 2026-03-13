describe OllamaChat::Tools::PatchFile do
  let(:chat) do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  let(:config) do
    chat.config
  end

  connect_to_ollama_server

  it 'can have name' do
    expect(described_class.new.name).to eq 'patch_file'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end

  it 'can be executed successfully with valid patch content' do
    # Create a test file first
    test_file = './tmp/test_patch_file.txt'
    File.write(test_file, "Hello\nWorld\n")

    diff_content = <<~DIFF
      @@ -1,2 +1,3 @@
       Hello
      +Second
       World
    DIFF

    tool_call = double(
      'ToolCall',
      function: double(
        name: 'patch_file',
        arguments: double(
          path: test_file,
          diff_content: diff_content
        )
      )
    )

    result = described_class.new.execute(tool_call, config: config)

    # Should return valid JSON
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.success).to eq true
    expect(json.path).to include('test_patch_file.txt')

    # Verify file was actually patched
    expect(File.exist?(test_file)).to be true
    content = File.read(test_file)
    expect(content).to include('Hello')
    expect(content).to include('Second')
    expect(content).to include('World')
  ensure
    # Clean up
    File.delete(test_file) if File.exist?(test_file)
  end

  it 'can handle execution errors gracefully when file does not exist' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'patch_file',
        arguments: double(
          path: './tmp/nonexistent.txt',
          diff_content: '@@ -1,1 +1,1 @@\n-Hello\n+World\n'
        )
      )
    )

    result = described_class.new.execute(tool_call, config: config)

    # Should return valid JSON with error
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to eq 'OllamaChat::InvalidPathError'
    expect(json.path).to be_nil
  end

  it 'can handle execution errors gracefully when path is not allowed' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'patch_file',
        arguments: double(
          path: '/etc/passwd',
          diff_content: '@@ -1,1 +1,1 @@\n-Hello\n+World\n'
        )
      )
    )

    result = described_class.new.execute(tool_call, config: config)

    # Should return valid JSON with error
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to eq 'OllamaChat::InvalidPathError'
    expect(json.path).to be_nil
  end

  it 'can handle execution errors gracefully when diff_content is missing' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'patch_file',
        arguments: double(
          path: './tmp/test.txt',
          diff_content: nil
        )
      )
    )

    result = described_class.new.execute(tool_call, config: config)

    # Should return valid JSON with error
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to eq 'ArgumentError'
  end

  it 'can handle exceptions gracefully' do
    test_file = './tmp/test.txt'
    File.write(test_file, "Hello\nWorld\n")

    tool_call = double(
      'ToolCall',
      function: double(
        name: 'patch_file',
        arguments: double(
          path: './tmp/test.txt',
          diff_content: '@@ -1,1 +1,1 @@\n-Hello\n+World\n'
        )
      )
    )

    tool = described_class.new
    expect(tool).to receive(:apply_patch).and_raise 'patch error'
    result = tool.execute(tool_call, config: config)

    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to eq 'RuntimeError'
    expect(json.path).to be_nil
  ensure
    # Clean up
    File.delete(test_file) if File.exist?(test_file)
  end
end
