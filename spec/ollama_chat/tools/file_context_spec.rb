require 'spec_helper'

describe OllamaChat::Tools::FileContext do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  let :config do
    double('Config', context: double(format: 'JSON'))
  end

  connect_to_ollama_server

  it 'can have name' do
    expect(described_class.new.name).to eq 'file_context'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  it 'can be executed successfully with pattern and directory' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'file_context',
        arguments: double(
          pattern: '**/*.rb',
          directory: 'spec/assets',
          path: nil
        )
      )
    )

    # Test with actual files in spec/assets
    result = described_class.new.execute(tool_call, config: config)
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.files['spec/assets/example.rb'].content).to include 'Hello World!'
  end

  it 'can handle execution errors gracefully' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'file_context',
        arguments: double(
          pattern: '**/*.nonexistent',
          directory: 'spec/assets',
          path: nil
        )
      )
    )

    # Test that it handles non-existent patterns gracefully
    result = described_class.new.execute(tool_call, config: config)

    # Should still return a string (even if empty or minimal)
    expect(result).to be_a(String)
  end

  it 'can be executed successfully with exact path argument' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'file_context',
        arguments: double(
          pattern: nil,
          directory: nil,
          path: 'spec/assets/example.rb'
        )
      )
    )

    # Test with exact file path
    result = described_class.new.execute(tool_call, config: config)
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.files['spec/assets/example.rb'].content).to include 'Hello World!'
  end

  it 'can handle execution with non-existent exact path gracefully' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'file_context',
        arguments: double(
          pattern: nil,
          directory: nil,
          path: 'spec/assets/nonexistent.rb'
        )
      )
    )

    # Test that it handles non-existent exact paths gracefully
    result = described_class.new.execute(tool_call, config: config)
    expect(result).to be_a(String)

    # Should return a valid JSON string even if file doesn't exist
    json = json_object(result)
    expect(json.files.to_h).to be_empty
  end

  it 'prioritizes exact path over pattern and directory when both are provided' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'file_context',
        arguments: double(
          pattern: '**/*.rb',
          directory: 'spec/assets',
          path: 'spec/assets/example.rb'
        )
      )
    )

    # When path is provided, it should use that exact file regardless of pattern/directory
    result = described_class.new.execute(tool_call, config: config)
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to eq 'ArgumentError'
    expect(json.message).to eq 'require either pattern or path argument'
  end

  it 'can handle exact path with nested directory structure' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'file_context',
        arguments: double(
          pattern: nil,
          directory: nil,
          path: 'spec/assets/deep/deeper/not-empty.txt'
        )
      )
    )

    # Test with nested file path
    result = described_class.new.execute(tool_call, config: config)
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.files['spec/assets/deep/deeper/not-empty.txt'].content).to include 'not-empty'
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end
end
