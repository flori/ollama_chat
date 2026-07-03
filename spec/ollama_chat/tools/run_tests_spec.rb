describe OllamaChat::Tools::RunTests do
  let(:chat) do
    OllamaChat::Chat.new(argv: chat_default_config)
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

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end

  context 'switchable test runner' do
    it 'supports rspec' do
      const_conf_as(
        'OC::OLLAMA::CHAT::TOOLS::TEST_RUNNER'  => 'rspec'
      )
      expect(described_class.new.expose.test_runner).to eq 'rspec'
    end

    it 'supports test-unit' do
      const_conf_as(
        'OC::OLLAMA::CHAT::TOOLS::TEST_RUNNER'  => 'test-unit'
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
          path:     ,
          coverage: nil
        )
      )
    )

    expect_any_instance_of(described_class).to receive(:check_path).
      with(path, chat.config).and_return path
    expect_any_instance_of(described_class).to receive(:run_tests).
      with(path, false).and_return(['yeah', true])

    result = described_class.new.execute(tool_call, chat:)

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
          path:     ,
          coverage: true
        )
      )
    )

    expect_any_instance_of(described_class).to receive(:check_path).
      with(path, chat.config).and_return path
    expect_any_instance_of(described_class).to receive(:run_tests).
      with(path, true).and_return(['yeah', true])

    result = described_class.new.execute(tool_call, chat:)

    json = json_object(result)
    expect(json.success).to be true
    expect(json.path).to eq 'spec/ollama_chat/tools/my_spec.rb'
    expect(json.status).to eq 'passed'
  end

  it 'can handle test failures' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'run_tests',
        arguments: double(
          path:     ,
          coverage: nil
        )
      )
    )

    expect_any_instance_of(described_class).to receive(:check_path).
      with(path, chat.config).and_return path
    expect_any_instance_of(described_class).to receive(:run_tests).
      with(path, false).and_return(['some errors', false])

    result = described_class.new.execute(tool_call, chat:)
    json = json_object(result)
    expect(json.success).to be false
    expect(json.status).to eq 'failed'
  end

  it 'can handle unexpected errors gracefully' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'run_tests',
        arguments: double(
          path:,
          coverage: nil
        )
      )
    )

    allow_any_instance_of(described_class).to receive(:check_path).
      and_raise(StandardError, 'Unexpected boom')

    result = described_class.new.execute(tool_call, chat:)
    json = json_object(result)
    expect(json.error).to eq 'StandardError'
    expect(json.message).to eq 'Unexpected boom'
  end

  context 'path auto-discovery' do
    let(:tool_call) do
      double(
        'ToolCall',
        function: double(
          name: 'run_tests',
          arguments: double(
            path: '',
            coverage: nil
          )
        )
      )
    end

    it 'defaults to ./spec if it exists' do
      path_expanded = Pathname.new('./spec').expand_path
      expect_any_instance_of(described_class).to receive(:run_tests).
        with(path_expanded, false).and_return(['ok', true])

      result = described_class.new.execute(tool_call, chat:)
      expect(json_object(result).path).to eq path_expanded.to_path
    end

    it 'raises ArgumentError if no test directory is found' do
      allow(File).to receive(:exist?).with('./spec').and_return(false)
      allow(File).to receive(:exist?).with('./test').and_return(false)
      allow(File).to receive(:exist?).with('./tests').and_return(false)

      result = described_class.new.execute(tool_call, chat:)
      expect(json_object(result).error).to eq 'ArgumentError'
    end
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

    result = described_class.new.execute(tool_call, chat:)
    json = json_object(result)
    expect(json.error).to eq 'OllamaChat::InvalidPathError'
  end

  it 'can handle non existing paths gracefully' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'run_tests',
        arguments: double(
          path: './spec/nixda_spec.rb',
          coverage: nil
        )
      )
    )

    result = described_class.new.execute(tool_call, chat:)
    json = json_object(result)
    expect(json.error).to eq 'OllamaChat::InvalidPathError'
  end
end
