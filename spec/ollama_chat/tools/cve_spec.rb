require 'spec_helper'

describe OllamaChat::Tools::CVE do
  let :chat do
    OllamaChat::Chat.new argv: chat_default_config
  end

  connect_to_ollama_server

  it 'can have name' do
    expect(described_class.new.name).to eq 'get_cve'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  it 'can be executed successfully' do
    # Mock the fetcher to return a valid CVE response
    cve_id = 'CVE-2023-12345'
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'get_cve',
        arguments: double(
          cve_id: cve_id
        )
      )
    )

    url = chat.config.tools.get_cve.url_template

    # Stub the HTTP request
    stub_request(:get, url % { cve_id: cve_id })
      .to_return(
        status: 200,
        body: '{"id": "CVE-2023-12345", "description": "Test vulnerability description"}',
        headers: { 'Content-Type' => 'application/json' }
      )

    result = described_class.new.execute(tool_call, config: chat.config)
    expect(result.id).to eq 'CVE-2023-12345'
    expect(result.description).to include('Test vulnerability description')
  end

  it 'can handle execution errors gracefully' do
    cve_id = 'CVE-2023-99999'
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'get_cve',
        arguments: double(
          cve_id: cve_id
        )
      )
    )

    url = chat.config.tools.get_cve.url_template

    stub_request(:get, url % { cve_id: cve_id })
      .to_return(status: 404, body: 'Not Found')

    result = described_class.new.execute(tool_call, config: chat.config)
    expect(result).to include('Failed to fetch CVE')
    expect(result).to include(cve_id)
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end
end
