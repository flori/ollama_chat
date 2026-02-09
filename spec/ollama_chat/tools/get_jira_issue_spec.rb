require 'spec_helper'

describe OllamaChat::Tools::GetJiraIssue do
  let :chat do
    OllamaChat::Chat.new argv: chat_default_config
  end

  connect_to_ollama_server

  it 'can have name' do
    expect(described_class.new.name).to eq 'get_jira_issue'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end

  context 'when configured via env var' do
    before do
      const_conf_as(
        'OllamaChat::EnvConfig::OLLAMA::CHAT::TOOLS::JIRA::URL'       => 'https://foobar.atlassian.net',
        'OllamaChat::EnvConfig::OLLAMA::CHAT::TOOLS::JIRA::USER'      => 'theuser',
        'OllamaChat::EnvConfig::OLLAMA::CHAT::TOOLS::JIRA::API_TOKEN' => 'secret',
      )
    end

    it 'can be executed successfully' do
      issue_key = 'FOO-1234'
      tool_call = double(
        'ToolCall',
        function: double(
          name: 'get_jira_issue',
          arguments: double(
            issue_key:
          )
        )
      )

      stub_request(:get, "https://foobar.atlassian.net/rest/api/3/issue/FOO-1234")
        .to_return(
          status: 200,
          body: "{\"issue_key\": \"FOO-1234\", \"description\": \"some description\"}",
          headers: {}
        )

      result = described_class.new.execute(tool_call, config: chat.config)

      json = json_object(result)
      expect(json.issue_key).to eq 'FOO-1234'
      expect(json.description).to eq 'some description'
    end

    it 'can handle execution errors gracefully' do
      issue_key = 'FOO-1234'
      tool_call = double(
        'ToolCall',
        function: double(
          name: 'get_jira_issue',
          arguments: double(
            issue_key:
          )
        )
      )

      stub_request(:get, "https://foobar.atlassian.net/rest/api/3/issue/FOO-1234")
        .to_return(status: 404, body: 'Not Found')

      result = described_class.new.execute(tool_call, config: chat.config)
      json = json_object(result)
      expect(json.error).to eq 'JSON::ParserError'
      expect(json.message).to eq 'require JSON data'
    end
  end

  context 'when not configured via env var' do
    it 'can handle execution errors gracefully' do
      issue_key = 'FOO-1234'
      tool_call = double(
        'ToolCall',
        function: double(
          name: 'get_jira_issue',
          arguments: double(
            issue_key:
          )
        )
      )

      stub_request(:get, "https://foobar.atlassian.net/rest/api/3/issue/FOO-1234")
        .to_return(status: 404, body: 'Not Found')

      result = described_class.new.execute(tool_call, config: chat.config)
      json = json_object(result)
      expect(json.error).to eq 'OllamaChat::ConfigMissingError'
    end
  end
end
