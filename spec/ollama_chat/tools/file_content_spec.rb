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
          directory: 'spec/assets'
        )
      )
    )

    # Test with actual files in spec/assets
    result = described_class.new.execute(tool_call, config: config)
    expect(result).to be_a(String)
    json = JSON.parse(result, object_class: JSON::GenericObject)
    expect(json.files['spec/assets/example.rb'].content).to include 'Hello World!'
  end

  it 'can handle execution errors gracefully' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'file_context',
        arguments: double(
          pattern: '**/*.nonexistent',
          directory: 'spec/assets'
        )
      )
    )

    # Test that it handles non-existent patterns gracefully
    result = described_class.new.execute(tool_call, config: config)

    # Should still return a string (even if empty or minimal)
    expect(result).to be_a(String)
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end
end
