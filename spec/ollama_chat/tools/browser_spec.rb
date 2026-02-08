require 'spec_helper'

describe OllamaChat::Tools::Browser do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  let :config do
    chat.config
  end

  connect_to_ollama_server

  it 'can have name' do
    expect(described_class.new.name).to eq 'browse'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end

  it 'can be executed successfully with a URL' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'browse',
        arguments: double(
          url: 'https://www.example.com'
        )
      )
    )

    # Test that system call is made with proper escaping
    expect_any_instance_of(described_class).to receive(:browse_url).
      and_return(double(success?: true, exitstatus: 0))

    result = described_class.new.execute(tool_call, config: config)

    # Should return valid JSON
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.success).to be true
    expect(json.exitstatus).to eq 0
    expect(json.message).to eq 'opening URL/file'
    expect(json.url).to eq 'https://www.example.com'
  end

  it 'can handle execution errors gracefully' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'browse',
        arguments: double(
          url: 'https://nonexistent-domain-12345.com'
        )
      )
    )

    expect_any_instance_of(described_class).to receive(:browse_url).
      and_return(double(success?: false, exitstatus: 1))

    result = described_class.new.execute(tool_call, config: config)

    # Should return valid JSON even with errors
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.success).to be false
    expect(json.exitstatus).to eq 1
    expect(json.message).to eq 'opening URL/file'
  end

  it 'can handle execution exceptions gracefully' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'browse',
        arguments: double(
          url: 'https://nonexistent-domain-12345.com'
        )
      )
    )

    expect_any_instance_of(described_class).to receive(:browse_url).
      and_raise("some kind of exception")
    result = described_class.new.execute(tool_call, config: config)

    # Should return valid JSON even with exceptions
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to eq 'RuntimeError'
    expect(json.message).to eq 'some kind of exception'
  end

  context 'when browser is configured' do
    before do
      const_conf_as('OllamaChat::EnvConfig::BROWSER' => 'the-bestest-browser')
    end

    it 'can be executed successfully with a URL' do
      tool_call = double(
        'ToolCall',
        function: double(
          name: 'browse',
          arguments: double(
            url: 'https://www.example.com'
          )
        )
      )

      # Test that system call is made with proper escaping
      expect_any_instance_of(described_class).to receive(:browse_url).
        and_return(double(success?: true, exitstatus: 0))

      result = described_class.new.execute(tool_call, config: config)

      # Should return valid JSON
      expect(result).to be_a(String)
      json = json_object(result)
      expect(json.success).to be true
      expect(json.exitstatus).to eq 0
      expect(json.message).to eq 'opening URL/file'
      expect(json.url).to eq 'https://www.example.com'
    end
  end
end
