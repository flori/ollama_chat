describe OllamaChat::Tools::DirectoryStructure do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  connect_to_ollama_server

  it 'can have name' do
    expect(described_class.new.name).to eq 'directory_structure'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  it 'can be executed successfully with path' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'directory_structure',
        arguments: double(
          path: 'spec/assets',
          max_depth: nil,
          suffix: nil,
          include_hidden: nil
        )
      )
    )

    result = described_class.new.execute(tool_call, chat:)

    # Should return valid JSON
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.size).to eq 24
    expect(described_class.summary_template(result:)).to eq \
      'was called.'
  end

  it 'can be executed successfully with no arguments (defaults)' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'directory_structure',
        arguments: double(
          path: nil,  # Should default to '.'
          max_depth: nil,
          suffix: nil,
          include_hidden: nil
        )
      )
    )

    result = described_class.new.execute(tool_call, chat:)

    # Should return valid JSON
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.size).to be_an Integer
  end

  it 'includes hidden files when include_hidden is true' do
    hidden_dir = File.join(Dir.pwd, '.tool_hidden_test')
    FileUtils.mkdir_p(hidden_dir)
    File.write(File.join(hidden_dir, '.secret'), 's')
    File.write(File.join(hidden_dir, 'visible.txt'), 'v')

    tool_call = double(
      'ToolCall',
      function: double(
        name: 'directory_structure',
        arguments: double(
          path:         hidden_dir,
          max_depth:    nil,
          suffix:       nil,
          include_hidden: true
        )
      )
    )

    result = described_class.new.execute(tool_call, chat:)
    json   = json_object(result)
    expect(json.map { _1['name'] }).to contain_exactly('.secret', 'visible.txt')
  ensure
    FileUtils.remove_entry(hidden_dir) if hidden_dir && File.directory?(hidden_dir)
  end

  it 'can handle execution errors gracefully' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'directory_structure',
        arguments: double(
          path: '/nonexistent/path',
          max_depth: nil,
          suffix: nil,
          include_hidden: nil
        )
      )
    )

    # Test that it handles non-existent paths gracefully
    result = described_class.new.execute(tool_call, chat:)

    # Should return valid JSON
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to eq 'Errno::ENOENT'
    expect(json.message).to eq 'No such file or directory @ dir_initialize - /nonexistent/path'
    expect(described_class.summary_template(result:)).to eq \
      'No such file or directory @ dir_initialize - /nonexistent/path'
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end
end
