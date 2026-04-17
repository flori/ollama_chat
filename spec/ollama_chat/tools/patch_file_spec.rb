describe OllamaChat::Tools::PatchFile do
  let(:chat) do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  connect_to_ollama_server

  let :tool do
    described_class.new
  end

  it 'can have name' do
    expect(tool.name).to eq 'patch_file'
  end

  it 'can have tool' do
    expect(tool.tool).to be_a Ollama::Tool
  end

  it 'can be converted to hash' do
    expect(tool.to_hash).to be_a Hash
  end

  it 'can be executed successfully with valid content' do
    # Create a test file first
    test_file = './tmp/test_patch_file.txt'
    File.write(test_file, "Hello\nWorld\n")

    new_content = "Hello\nSecond\nWorld\n"

    # Mock arguments to respond to .full? as used in the tool
    args_double = double('Arguments',
      path: double(full?: test_file),
      content: double(full?: new_content)
    )

    tool_call = double(
      'ToolCall',
      function: double(
        name: 'patch_file',
        arguments: args_double
      )
    )

    # Mock Tempfile and system to avoid launching real vimdiff
    tmp_double = double('Tempfile', write: true, flush: true, path: '/tmp/test_patch')
    expect(Tempfile).to receive(:create).and_yield(tmp_double)

    # Simulate user applying changes via diffget (changing the file)
    allow(tool).to receive(:system).and_return(true)

    allow(tool).to receive(:digest).and_return 'theold', 'thenew'

    result = tool.execute(tool_call, chat:)

    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.success).to eq true
    expect(json.path).to include('test_patch_file.txt')
  ensure
    File.delete(test_file) if File.exist?(test_file)
  end

  it 'can handle execution errors gracefully when file does not exist' do
    args_double = double('Arguments',
      path: double(full?: './tmp/nonexistent.txt'),
      content: double(full?: 'Some content')
    )
    tool_call = double('ToolCall', function: double(name: 'patch_file', arguments: args_double))

    result = tool.execute(tool_call, chat:)

    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to eq 'OllamaChat::InvalidPathError'
  end

  it 'can handle execution errors gracefully when path is not allowed' do
    args_double = double('Arguments',
      path: double(full?: '/etc/passwd'),
      content: double(full?: 'Some content')
    )
    tool_call = double('ToolCall', function: double(name: 'patch_file', arguments: args_double))

    result = tool.execute(tool_call, chat:)

    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to eq 'OllamaChat::InvalidPathError'
  end

  it 'can handle execution errors gracefully when content is missing' do
    args_double = double('Arguments',
      path: double(full?: './tmp/test.txt'),
      content: double(full?: nil)
    )
    tool_call = double('ToolCall', function: double(name: 'patch_file', arguments: args_double))

    result = tool.execute(tool_call, chat:)

    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to eq 'ArgumentError'
  end

  it 'can handle exceptions gracefully' do
    test_file = './tmp/test_exception.txt'
    File.write(test_file, "Hello\nWorld\n")

    args_double = double('Arguments',
      path: double(full?: test_file),
      content: double(full?: 'New Content')
    )
    tool_call = double('ToolCall', function: double(name: 'patch_file', arguments: args_double))

    expect(tool).to receive(:apply_patch).and_raise 'patch error'
    result = tool.execute(tool_call, chat:)

    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to eq 'RuntimeError'
  ensure
    File.delete(test_file) if File.exist?(test_file)
  end
end
