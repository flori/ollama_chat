require 'spec_helper'

describe OllamaChat::Tools::DirectoryStructure do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  let :config do
    chat.config
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
        )
      )
    )

    result = described_class.new.execute(tool_call, config:)

    # Should return valid JSON
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.size).to eq 18
  end

  it 'can be executed successfully with no arguments (defaults)' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'directory_structure',
        arguments: double(
          path: nil,  # Should default to '.'
        )
      )
    )

    result = described_class.new.execute(tool_call, config:)

    # Should return valid JSON
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.size).to be_an Integer
  end

  it 'can handle execution errors gracefully' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'directory_structure',
        arguments: double(
          path: '/nonexistent/path',
        )
      )
    )

    # Test that it handles non-existent paths gracefully
    result = described_class.new.execute(tool_call, config:)

    # Should return valid JSON
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to eq 'Errno::ENOENT'
    expect(json.message).to eq 'No such file or directory @ dir_initialize - /nonexistent/path'
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end
end
