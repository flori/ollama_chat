describe OllamaChat::Tools::GetRFC do
  let :chat do
    OllamaChat::Chat.new argv: chat_default_config
  end

  connect_to_ollama_server

  it 'can have name' do
    expect(described_class.new.name).to eq 'get_rfc'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end

  it 'can be executed successfully' do
    # Mock the fetcher to return a valid RFC response
    rfc_id = '1234'
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'get_rfc',
        arguments: double(
          rfc_id: rfc_id
        )
      )
    )

    url = chat.config.tools.functions.get_rfc.url

    # Stub the HTTP request
    stub_request(:get, url % { rfc_id: })
      .to_return(
        status: 200,
        body: 'RFC 1234: Simple Network Protocol',
        headers: { 'Content-Type' => 'text/plain' }
      )

    result = described_class.new.execute(tool_call, config: chat.config)
    json = json_object(result)
    expect(json.rfc_id).to eq rfc_id
    expect(json.content).to include('RFC 1234')
  end

  it 'can handle execution errors gracefully' do
    rfc_id = '9999'
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'get_rfc',
        arguments: double(
          rfc_id: rfc_id
        )
      )
    )

    url = chat.config.tools.functions.get_rfc.url

    stub_request(:get, url % { rfc_id: })
      .to_return(status: 404, body: 'Not Found')

    result = described_class.new.execute(tool_call, config: chat.config)
    json = json_object(result)
    expect(json.error).to be_a String
    expect(json.message).to be_a String
  end
end
