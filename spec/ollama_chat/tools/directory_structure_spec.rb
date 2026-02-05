require 'spec_helper'

describe OllamaChat::Tools::DirectoryStructure do
  let(:chat) do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  connect_to_ollama_server

  it 'can have name' do
    expect(described_class.new.name).to eq 'directory_structure'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  it 'can be executed successfully with path and depth' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'directory_structure',
        arguments: double(
          path: 'spec/assets',
          depth: 3
        )
      )
    )

    result = described_class.new.execute(tool_call)

    # Should return valid JSON
    expect(result).to be_a(String)
    json = JSON.parse(result, object_class: JSON::GenericObject)
    expect(json.size).to eq 18
  end

  it 'can be executed successfully with no arguments (defaults)' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'directory_structure',
        arguments: double(
          path: nil,  # Should default to '.'
          depth: nil  # Should default to 2
        )
      )
    )

    result = described_class.new.execute(tool_call)

    # Should return valid JSON
    expect(result).to be_a(String)
    json = JSON.parse(result, object_class: JSON::GenericObject)
    expect(json.size).to be > 18
  end

  it 'can handle execution errors gracefully' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'directory_structure',
        arguments: double(
          path: '/nonexistent/path',
          depth: 2
        )
      )
    )

    # Test that it handles non-existent paths gracefully
    result = described_class.new.execute(tool_call)

    # Should return valid JSON
    expect(result).to be_a(String)
    json = JSON.parse(result, object_class: JSON::GenericObject)
    expect(json.error).to eq 'Errno::ENOENT'
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end
end
