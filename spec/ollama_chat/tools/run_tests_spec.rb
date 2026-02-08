require 'spec_helper'

describe OllamaChat::Tools::RunTests do
  let(:chat) do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  let(:config) do
    chat.config
  end

  connect_to_ollama_server

  let :path do
    'spec/ollama_chat/tools/my_spec.rb'
  end

  it 'can have name' do
    expect(described_class.new.name).to eq 'run_tests'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  context 'switchable test runner' do
    it 'supports rspec' do
      const_conf_as(
        'OllamaChat::EnvConfig::OLLAMA::CHAT::TOOLS::RUN_TESTS_TEST_RUNNER'  => 'rspec'
      )
      expect(described_class.new.expose.test_runner).to eq 'rspec'
    end

    it 'supports test-unit' do
      const_conf_as(
        'OllamaChat::EnvConfig::OLLAMA::CHAT::TOOLS::RUN_TESTS_TEST_RUNNER'  => 'test-unit'
      )
      expect(described_class.new.expose.test_runner).to eq 'test-unit'
    end
  end

  it 'can be executed successfully with a path' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'run_tests',
        arguments: double(
          path: ,
          coverage: nil
        )
      )
    )

    expect_any_instance_of(described_class).to receive(:run_tests).
      with(path, false).and_return(['yeah', true])

    result = described_class.new.execute(tool_call, config: config)

    json = json_object(result)
    expect(json.success).to be true
    expect(json.path).to eq 'spec/ollama_chat/tools/my_spec.rb'
    expect(json.status).to eq 'passed'
  end

  it 'can be executed successfully with a path and coverage' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'run_tests',
        arguments: double(
          path: ,
          coverage: true
        )
      )
    )

    expect_any_instance_of(described_class).to receive(:run_tests).
      with(path, true).and_return(['yeah', true])

    result = described_class.new.execute(tool_call, config: config)

    json = json_object(result)
    expect(json.success).to be true
    expect(json.path).to eq 'spec/ollama_chat/tools/my_spec.rb'
    expect(json.status).to eq 'passed'
  end

  it 'can handle invalid paths gracefully' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'run_tests',
        arguments: double(
          path: 'nonexistent/path',
          coverage: nil
        )
      )
    )

    expect_any_instance_of(described_class).to receive(:run_tests).
      with('nonexistent/path', false).and_return(['nope', false])

    result = described_class.new.execute(tool_call, config: config)

    json = json_object(result)
    expect(json.success).to be false
    expect(json.status).to eq 'failed'
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end
end
