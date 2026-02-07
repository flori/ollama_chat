require 'spec_helper'

describe OllamaChat::Tools::FileWriter do
  let(:chat) do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  let(:config) do
    chat.config
  end

  connect_to_ollama_server

  it 'can have name' do
    expect(described_class.new.name).to eq 'write_file'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  it 'can be executed successfully with overwrite mode' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'write_file',
        arguments: double(
          path: './tmp/test_write_file.txt',
          content: 'Hello, World!',
          mode: 'overwrite'
        )
      )
    )

    result = described_class.new.execute(tool_call, config: config)

    # Should return valid JSON
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.success).to eq true
    expect(json.path).to include('test_write_file.txt')

    # Verify file was actually written
    expect(File.exist?('./tmp/test_write_file.txt')).to be true
    expect(File.read('./tmp/test_write_file.txt')).to eq 'Hello, World!'
  ensure
    # Clean up
    File.delete('./tmp/test_write_file.txt') if File.exist?('./tmp/test_write_file.txt')
  end

  it 'can be executed successfully with append mode' do
    # First write some initial content
    initial_content = 'Initial content\n'
    File.secure_write('./tmp/test_append_file.txt', initial_content)

    tool_call = double(
      'ToolCall',
      function: double(
        name: 'write_file',
        arguments: double(
          path: './tmp/test_append_file.txt',
          content: 'Appended content\n',
          mode: 'append'
        )
      )
    )

    result = described_class.new.execute(tool_call, config: config)

    # Should return valid JSON
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.success).to be true
    expect(json.path).to include('test_append_file.txt')

    # Verify file was actually appended
    expect(File.exist?('./tmp/test_append_file.txt')).to be true
    content = File.read('./tmp/test_append_file.txt')
    expect(content).to include('Initial content')
    expect(content).to include('Appended content')
  ensure
    # Clean up
    File.delete('./tmp/test_append_file.txt') if File.exist?('./tmp/test_append_file.txt')
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

    result = described_class.new.execute(tool_call, config: config)

    # Should return valid JSON with error
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to eq 'ArgumentError'
    expect(json.message).to include('is not within allowed directories')
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end
end
