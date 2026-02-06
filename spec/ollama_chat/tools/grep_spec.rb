require 'spec_helper'

describe OllamaChat::Tools::Grep do
  let(:chat) do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  connect_to_ollama_server

  it 'can have name' do
    expect(described_class.new.name).to eq 'execute_grep'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  it 'can be executed successfully with pattern and path in spec/assets' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'execute_grep',
        arguments: double(
          pattern: 'Hello World',
          path: 'spec/assets',
          max_results: nil
        )
      )
    )

    result = described_class.new.execute(tool_call, config: chat.config)

    # Should return a JSON string
    expect(result).to be_a String
    json = JSON.parse(result, object_class: JSON::GenericObject)
    expect(json.cmd).to include('grep')
    expect(json.cmd).to include('Hello\\ World')
    expect(json.cmd).to include('spec/assets')
    expect(json.result).to include('Hello World!')
  end

  it 'can be executed successfully with max_results parameter' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'execute_grep',
        arguments: double(
          pattern: 'class',
          path: 'spec/assets',
          max_results: 5
        )
      )
    )

    result = described_class.new.execute(tool_call, config: chat.config)

    # Should return a JSON string
    expect(result).to be_a String
    json = JSON.parse(result, object_class: JSON::GenericObject)
    expect(json.cmd).to include('grep')
    expect(json.cmd).to include('-m 5')
    expect(json.result).to match(/class="body--html"/)
  end

  it 'can handle execution errors gracefully' do
    # Test with a non-existent pattern
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'execute_grep',
        arguments: double(
          pattern: 'nonexistent_pattern',
          path: 'spec/assets',
          max_results: nil
        )
      )
    )

    result = described_class.new.execute(tool_call, config: chat.config)

    # Should return a JSON string even with no matches
    expect(result).to be_a String
    json = JSON.parse(result, object_class: JSON::GenericObject)
    expect(json.cmd).to include('grep')
    expect(json.result).to be_a String
  end

  it 'can handle non-existent paths gracefully' do
    # Test with a non-existent path
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'execute_grep',
        arguments: double(
          pattern: 'test',
          path: '/nonexistent/path/that/does/not/exist',
          max_results: nil
        )
      )
    )

    result = described_class.new.execute(tool_call, config: chat.config)

    # Should return a JSON string with error information
    expect(result).to be_a String
    json = JSON.parse(result, object_class: JSON::GenericObject)
    expect(json.result).to match(%r(grep: /nonexistent/path/that/does/not/exist))
  end

  it 'can handle thrown exceptions' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'execute_grep',
        arguments: double(
          pattern: 'test',
          path: '/nonexistent/path/that/does/not/exist',
          max_results: nil
        )
      )
    )

    expect(OllamaChat::Utils::Fetcher).to receive(:execute).
      and_raise('my error')
    result = described_class.new.execute(tool_call, config: chat.config)

    expect(result).to be_a String
    json = JSON.parse(result, object_class: JSON::GenericObject)
    expect(json.error).to eq 'RuntimeError'
    expect(json.message).to eq 'my error'
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end

  context 'when searching in spec/assets directory' do
    it 'finds content from example.rb file' do
      tool_call = double(
        'ToolCall',
        function: double(
          name: 'execute_grep',
          arguments: double(
            pattern: 'Hello World!',
            path: 'spec/assets',
            max_results: nil
          )
        )
      )

      result = described_class.new.execute(tool_call, config: chat.config)

      # Should find the example content
      json = JSON.parse(result, object_class: JSON::GenericObject)
      expect(json.result).to include('Hello World!')
      expect(json.result).to include('example.rb')
    end
  end
end
