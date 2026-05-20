describe OllamaChat::Tools::GetGHR do
  let :chat do
    OllamaChat::Chat.new argv: chat_default_config
  end

  connect_to_ollama_server

  before do
    const_conf_as('OC::OLLAMA::CHAT::TOOLS::GHR_URL' => 'https://ghr.example.com')
  end

  it 'can have name' do
    expect(described_class.new.name).to eq 'get_ghr'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end

  it 'can be executed successfully for a specific repository' do
    user = 'acidanthera'
    repo = 'AppleALC'

    tool_call = double(
      'ToolCall',
      function: double(
        name: 'get_ghr',
        arguments: double(
          user: double(full?: user),
          repo: double(full?: repo)
        )
      )
    )

    url = "https://ghr.example.com/repos/#{user}:#{repo}.json"

    stub_request(:get, url)
      .to_return(
        status: 200,
        body: '[{"version": "1.0", "date": "2023-01-01"}]',
        headers: { 'Content-Type' => 'application/json' }
      )

    result = described_class.new.execute(tool_call, chat:)
    json = json_object(result)

    expect(json.user).to eq user
    expect(json.repo).to eq repo
    expect(json.releases).to be_a Array
    expect(json.releases.first.version).to eq '1.0'
  end

  it 'can be executed successfully for an overview' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'get_ghr',
        arguments: double(
          user: double(full?: nil),
          repo: double(full?: nil)
        )
      )
    )

    url = "https://ghr.example.com/repos.json"

    stub_request(:get, url)
      .to_return(
        status: 200,
        body: '["repo1", "repo2"]',
        headers: { 'Content-Type' => 'application/json' }
      )

    result = described_class.new.execute(tool_call, chat:)
    json = json_object(result)

    expect(json.repos).to include('repo1', 'repo2')
  end

  it 'handles invalid argument combinations (only one provided)' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'get_ghr',
        arguments: double(
          user: double(full?: 'acidanthera'),
          repo: double(full?: nil)
        )
      )
    )

    result = described_class.new.execute(tool_call, chat:)
    json = json_object(result)

    expect(json.error).to eq 'OllamaChat::ToolFunctionArgumentError'
    expect(json.message).to include('Both user and repo must be provided')
  end

  it 'can handle execution errors gracefully' do
    user = 'acidanthera'
    repo = 'AppleALC'

    tool_call = double(
      'ToolCall',
      function: double(
        name: 'get_ghr',
        arguments: double(
          user: double(full?: user),
          repo: double(full?: repo)
        )
      )
    )

    url = "https://ghr.example.com/repos/#{user}:#{repo}.json"

    stub_request(:get, url).to_return(status: 404, body: 'Not Found')

    result = described_class.new.execute(tool_call, chat:)
    json = json_object(result)

    expect(json.error).to eq 'JSON::ParserError'
    expect(json.message).to eq 'require JSON data'
  end
end
