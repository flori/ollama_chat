require 'spec_helper'

describe OllamaChat::Tools::SearchWeb do
  let(:chat) do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  let(:config) do
    chat.config
  end

  connect_to_ollama_server

  it 'can have name' do
    expect(described_class.new.name).to eq 'search_web'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  it 'can be executed successfully with a query' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'search_web',
        arguments: double(
          query: 'Ruby programming',
          num_results: nil
        )
      )
    )

    # Mock the search_web method to return a valid response
    expect(chat).to receive(:search_web).with('Ruby programming', 5).and_return([
      'https://www.ruby-lang.org',
      'https://ruby-doc.org'
    ])

    result = described_class.new.execute(tool_call, config: config, chat: chat)

    # Should return valid JSON
    expect(result).to be_a(String)
    json = JSON.parse(result, object_class: JSON::GenericObject)
    expect(json.query).to eq 'Ruby programming'
    expect(json.url).to be_a(Array)
    expect(json.url.length).to be >= 1
  end

  it 'can be executed successfully with a query and custom num_results' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'search_web',
        arguments: double(
          query: 'Ruby programming',
          num_results: 3
        )
      )
    )

    # Mock the search_web method to return a valid response
    expect(chat).to receive(:search_web).with('Ruby programming', 3).and_return([
      'https://www.ruby-lang.org'
    ])

    result = described_class.new.execute(tool_call, config: config, chat: chat)

    # Should return valid JSON
    expect(result).to be_a(String)
    json = JSON.parse(result, object_class: JSON::GenericObject)
    expect(json.query).to eq 'Ruby programming'
    expect(json.url).to be_a(Array)
    expect(json.url.length).to eq 1
  end

  it 'can handle execution errors gracefully' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'search_web',
        arguments: double(
          query: 'Ruby programming',
          num_results: nil
        )
      )
    )

    # Mock the search_web method to raise an exception
    expect(chat).to receive(:search_web).and_raise('Network error')

    result = described_class.new.execute(tool_call, config: config, chat: chat)

    # Should return valid JSON even with errors
    expect(result).to be_a(String)
    json = JSON.parse(result, object_class: JSON::GenericObject)
    expect(json.error).to eq 'RuntimeError'
    expect(json.message).to eq 'Network error'
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end
end
