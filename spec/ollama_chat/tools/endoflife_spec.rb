require 'spec_helper'

describe OllamaChat::Tools::EndOfLife do
  let :chat do
    OllamaChat::Chat.new argv: chat_default_config
  end

  connect_to_ollama_server

  it 'can have name' do
    expect(described_class.new.name).to eq 'get_endoflife'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  it 'can be executed successfully' do
    # Mock the fetcher to return a valid endoflife response
    product = 'ruby'
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'get_endoflife',
        arguments: double(
          product: product
        )
      )
    )

    url = chat.config.tools.get_endoflife.url

    # Stub the HTTP request
    stub_request(:get, url % { product: })
      .to_return(
        status: 200,
        body: '{ "cycle": "3.1", "releaseDate": "2023-05-01", "eol": "2026-05-01" }',
        headers: { 'Content-Type' => 'application/json' }
      )

    result = described_class.new.execute(tool_call, config: chat.config)
    json = json_object(result)
    expect(json.cycle).to eq '3.1'
    expect(json.releaseDate).to eq '2023-05-01'
    expect(json.eol).to eq '2026-05-01'
  end

  it 'can handle execution errors gracefully' do
    product = 'nonexistent-product'
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'get_endoflife',
        arguments: double(
          product: product
        )
      )
    )

    url = chat.config.tools.get_endoflife.url

    stub_request(:get, url % { product: product })
      .to_return(status: 404, body: 'Not Found')

    result = described_class.new.execute(tool_call, config: chat.config)
    json = json_object(result)
    expect(json.error).to eq 'JSON::ParserError'
    expect(json.message).to eq 'require JSON data'
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end
end
