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

  let :test_write_file do
    "./tmp/test_write_file_#{Tins::Token.new(bits: 128)}.txt"
  end

  it 'can be executed successfully with overwrite mode on new file' do
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
    expect(described_class.summary_template(result:)).
      to include('Wrote 13.0 B (4.0 T) to file')

    # Verify file was actually written
    expect(File.exist?(test_write_file)).to be true
    expect(File.read(test_write_file)).to eq 'Hello, World!'
  ensure
    # Clean up
    File.delete(test_write_file) if File.exist?(test_write_file)
  end

  it 'can be executed successfully with overwrite mode on existing file with confirmation' do
    # Pre-create the file
    File.write(test_write_file, 'Old content')

    expect(chat).to receive(:confirm?).and_return(true)

    tool_call = double(
      'ToolCall',
      function: double(
        name: 'write_file',
        arguments: double(
          path: test_write_file,
          content: 'New content',
          mode: 'overwrite'
        )
      )
    )

    result = described_class.new.execute(tool_call, chat:)

    json = json_object(result)
    expect(json.success).to eq true
    expect(File.read(test_write_file)).to eq 'New content'
    expect(described_class.summary_template(result:)).
      to include('Wrote 11.0 B (4.0 T) to file')
  ensure
    File.delete(test_write_file) if File.exist?(test_write_file)
  end

  it 'rejects overwrite when user declines confirmation' do
    # Pre-create the file
    File.write(test_write_file, 'Old content')

    expect(chat).to receive(:confirm?).and_return(false)

    tool_call = double(
      'ToolCall',
      function: double(
        name: 'write_file',
        arguments: double(
          path: test_write_file,
          content: 'New content',
          mode: 'overwrite'
        )
      )
    )

    result = described_class.new.execute(tool_call, chat:)

    json = json_object(result)
    expect(json.error).to eq 'OllamaChat::ToolFunctionArgumentError'
    expect(json.message).to include('Write rejected')
    expect(described_class.summary_template(result:)).
      to include('Write rejected')
    expect(File.read(test_write_file)).to eq 'Old content'
  ensure
    File.delete(test_write_file) if File.exist?(test_write_file)
  end

  it 'can be executed successfully with append mode on existing file' do
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
    expect(described_class.summary_template(result:)).
      to include('Wrote 18.0 B (6.0 T) to file')

    # Verify file was actually appended
    expect(File.exist?(test_write_file)).to be true
    content = File.read(test_write_file)
    expect(content).to include('Initial content')
    expect(content).to include('Appended content')
  ensure
    # Clean up
    File.delete(test_write_file) if File.exist?(test_write_file)
  end

  it 'can be executed successfully with append mode on new file with confirmation' do
    expect(chat).to receive(:confirm?).and_return(true)

    tool_call = double(
      'ToolCall',
      function: double(
        name: 'write_file',
        arguments: double(
          path: test_write_file,
          content: 'First content\n',
          mode: 'append'
        )
      )
    )

    result = described_class.new.execute(tool_call, chat:)

    json = json_object(result)
    expect(json.success).to eq true
    expect(File.read(test_write_file)).to eq 'First content\n'
    expect(described_class.summary_template(result:)).
      to include('Wrote 15.0 B (5.0 T) to file')
  ensure
    File.delete(test_write_file) if File.exist?(test_write_file)
  end

  it 'rejects append when user declines confirmation for new file' do
    expect(chat).to receive(:confirm?).and_return(false)

    tool_call = double(
      'ToolCall',
      function: double(
        name: 'write_file',
        arguments: double(
          path: test_write_file,
          content: 'First content\n',
          mode: 'append'
        )
      )
    )

    result = described_class.new.execute(tool_call, chat:)

    json = json_object(result)
    expect(json.error).to eq 'OllamaChat::ToolFunctionArgumentError'
    expect(json.message).to include('Write rejected')
    expect(described_class.summary_template(result:)).
      to include('Write rejected')
    expect(File.exist?(test_write_file)).to be false
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
    expect(described_class.summary_template(result:)).
      to include('is not within allowed directories')
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
    expect(described_class.summary_template(result:)).
      to include('Invalid mode')
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
    expect(described_class.summary_template(result:)).to eq \
      'Failed to write to file: some error'
  end

  describe 'syntax check integration' do
    let :test_rb_file do
      "./tmp/test_syntax_#{Tins::Token.new(bits: 128)}.rb"
    end

    after do
      File.delete(test_rb_file) if File.exist?(test_rb_file)
    end

    it 'includes syntax_check on valid .rb file (omits clean pass)' do
      expect(chat).to receive(:syntax_checker_for).and_return(nil)

      tool_call = double(
        'ToolCall',
        function: double(
          name: 'write_file',
          arguments: double(
            path: test_rb_file,
            content: "def foo\n  42\nend\n",
            mode: 'overwrite'
          )
        )
      )

      result = described_class.new.execute(tool_call, chat:)
      json = json_object(result)
      expect(json.success).to eq true
      expect(json.syntax_check).to be_nil
    end

    it 'includes syntax_check fail on broken .rb file' do
      checker = double('checker', cmd: ['ruby', '-wc'])
      expect(chat).to receive(:syntax_checker_for).and_return(checker)
      expect(chat).to receive(:run_syntax_check).with(checker, any_args)
        .and_return({ status: 'fail',
                      output: "test.rb:2: syntax error, unexpected 'end'" })

      tool_call = double(
        'ToolCall',
        function: double(
          name: 'write_file',
          arguments: double(
            path: test_rb_file,
            content: "def foo\nend\nend\n",
            mode: 'overwrite'
          )
        )
      )

      result = described_class.new.execute(tool_call, chat:)
      json = json_object(result)
      expect(json.success).to eq true
      expect(json.message).to include('❌ Syntax error detected')
      expect(json.syntax_check[:status]).to eq 'fail'
    end

    it 'omits syntax_check for non-matching extension' do
      expect(chat).to receive(:syntax_checker_for).and_return(nil)

      tool_call = double(
        'ToolCall',
        function: double(
          name: 'write_file',
          arguments: double(
            path: test_write_file,
            content: 'plain text',
            mode: 'overwrite'
          )
        )
      )

      result = described_class.new.execute(tool_call, chat:)
      json = json_object(result)
      expect(json.success).to eq true
      expect(json.syntax_check).to be_nil
    end
  end
end
