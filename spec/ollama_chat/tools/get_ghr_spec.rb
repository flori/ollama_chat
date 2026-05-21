describe OllamaChat::Tools::GetGHR do
  let :chat do
    OllamaChat::Chat.new argv: chat_default_config
  end

  connect_to_ollama_server

  before do
    const_conf_as('OC::OLLAMA::CHAT::TOOLS::GHR_URL' => URI.parse('https://ghr.example.com'))
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
          user:,
          repo:,
          offset: nil,
          limit: nil
        )
      )
    )

    url = "https://ghr.example.com/repos/#{user}:#{repo}/releases.json"

    stub_request(:get, url)
      .to_return(
        status: 200,
        body: '{"releases": [{"version": "1.0", "date": "2023-01-01"}]}',
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
          user: nil,
          repo: nil,
          offset: nil,
          limit: nil
        )
      )
    )

    url = "https://ghr.example.com/repos.json"

    stub_request(:get, url)
      .to_return(
        status: 200,
        body: '{"repos": ["repo1", "repo2"], "total": 2}',
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
          user: 'acidanthera',
          repo: nil,
          offset: nil,
          limit: nil
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
          user:,
          repo:,
          offset: nil,
          limit: nil
        )
      )
    )

    url = "https://ghr.example.com/repos/#{user}:#{repo}/releases.json"

    stub_request(:get, url).to_return(status: 404, body: 'Not Found')

    result = described_class.new.execute(tool_call, chat:)
    json = json_object(result)

    expect(json.error).to eq 'OllamaChat::HTTPError'
    expect(json.message).to eq 'request failed with status 404'
  end

  it 'can be executed successfully for a specific repository with pagination' do
    user = 'acidanthera'
    repo = 'AppleALC'
    offset = 0
    limit = 10

    tool_call = double(
      'ToolCall',
      function: double(
        name: 'get_ghr',
        arguments: double(
          user:,
          repo:,
          offset:,
          limit:
        )
      )
    )

    url = "https://ghr.example.com/repos/#{user}:#{repo}/releases.json?offset=#{offset}&limit=#{limit}"

    stub_request(:get, url)
      .to_return(
        status: 200,
        body: '{"releases": [{"version": "1.0", "date": "2023-01-01"}]}',
        headers: { 'Content-Type' => 'application/json' }
      )

    result = described_class.new.execute(tool_call, chat:)
    expect(result).to be_a String
  end

  it 'can be executed successfully for an overview with pagination' do
    offset = 10
    limit = 20

    tool_call = double(
      'ToolCall',
      function: double(
        name: 'get_ghr',
        arguments: double(
          user: nil,
          repo: nil,
          offset:,
          limit:
        )
      )
    )

    url = "https://ghr.example.com/repos.json?offset=#{offset}&limit=#{limit}"

    stub_request(:get, url)
      .to_return(
        status: 200,
        body: '{"repos": ["repo1", "repo2"], "total": 2}',
        headers: { 'Content-Type' => 'application/json' }
      )

    result = described_class.new.execute(tool_call, chat:)
    expect(result).to be_a String
  end

  it 'handles pagination correctly when only one parameter is provided' do
    # Case 1: Only limit for a specific repo
    user = 'acidanthera'
    repo = 'AppleALC'
    limit = 5

    tool_call_limit = double(
      'ToolCall',
      function: double(
        name: 'get_ghr',
        arguments: double(user:, repo:, offset: nil, limit:)
      )
    )

    url_limit = "https://ghr.example.com/repos/#{user}:#{repo}/releases.json?limit=#{limit}"
    stub_request(:get, url_limit).
      to_return(status: 200, body: '{"releases": []}', headers: { 'Content-Type' => 'application/json' })

    expect { described_class.new.execute(tool_call_limit, chat:) }.not_to raise_error

    # Case 2: Only offset for an overview
    offset = 5
    tool_call_offset = double(
      'ToolCall',
      function: double(
        name: 'get_ghr',
        arguments: double(user: nil, repo: nil, offset:, limit: nil)
      )
    )

    url_offset = "https://ghr.example.com/repos.json?offset=#{offset}"
    stub_request(:get, url_offset).
      to_return(status: 200, body: '{"repos": [], "total": 0}', headers: { 'Content-Type' => 'application/json' })

    expect { described_class.new.execute(tool_call_offset, chat:) }.not_to raise_error
  end
end
