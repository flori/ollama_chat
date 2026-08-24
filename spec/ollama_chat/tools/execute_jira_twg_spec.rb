describe OllamaChat::Tools::ExecuteJIRATWG do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  connect_to_ollama_server

  it 'can have name' do
    expect(described_class.new.name).to eq 'execute_jira_twg'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end

  context 'when executed successfully' do
    let(:command) { 'jira workitem get DEV-29042' }

    before do
      expect(OC::OLLAMA::CHAT::TOOLS::JIRA).to receive(:TWG?).and_return('true')
      system('true') # reset $? to exit 0
      expect(OllamaChat::Utils::Fetcher).to receive(:execute)
        .with(%w[true jira workitem get DEV-29042])
        .and_return('{ "key": "DEV-29042" }')
    end

    it 'returns JSON containing cmd and result' do
      tool_call = double(
        'ToolCall',
        function: double(
          name: 'execute_jira_twg',
          arguments: double(command:)
        )
      )

      result = described_class.new.execute(tool_call, chat:)

      expect(result).to be_a String
      json = json_object(result)
      expect(json.cmd).to include('true')
      expect(json.cmd).to include('DEV-29042')
      expect(json.result).to eq '{ "key": "DEV-29042" }'
      expect(json.message).to include('DEV-29042')
    end
  end

  context 'when command contains quoted arguments' do
    let(:command) { 'jira workitem query --jql "project = DEV AND status != Done"' }

    before do
      expect(OC::OLLAMA::CHAT::TOOLS::JIRA).to receive(:TWG?).and_return('true')
      system('true') # reset $? to exit 0
      expect(OllamaChat::Utils::Fetcher).to receive(:execute)
        .with(['true', 'jira', 'workitem', 'query', '--jql', 'project = DEV AND status != Done'])
        .and_return('{ "issues": [] }')
    end

    it 'parses shell-quoted arguments correctly' do
      tool_call = double(
        'ToolCall',
        function: double(
          name: 'execute_jira_twg',
          arguments: double(command:)
        )
      )

      result = described_class.new.execute(tool_call, chat:)

      json = json_object(result)
      expect(json.result).to eq '{ "issues": [] }'
    end
  end

  context 'when command is missing or invalid' do
    it 'returns an error JSON due to ToolFunctionArgumentError' do
      tool_call = double(
        'ToolCall',
        function: double(
          name: 'execute_jira_twg',
          arguments: double(command: nil)
        )
      )

      result = described_class.new.execute(tool_call, chat:)

      json = json_object(result)
      expect(json.error).to eq('OllamaChat::ToolFunctionArgumentError')
    end
  end

  context 'when fetcher raises an exception' do
    before do
      expect(OC::OLLAMA::CHAT::TOOLS::JIRA).to receive(:TWG?).and_return('true')
      expect(OllamaChat::Utils::Fetcher).to receive(:execute)
        .and_raise('twg: command not found')
    end

    it 'returns a JSON with the error class and message' do
      tool_call = double(
        'ToolCall',
        function: double(
          name: 'execute_jira_twg',
          arguments: double(command: 'user get')
        )
      )

      result = described_class.new.execute(tool_call, chat:)

      json = json_object(result)
      expect(json.error).to eq('RuntimeError')
      expect(json.message).to include('twg: command not found')
    end
  end

  context 'when twg exits with non-zero status' do
    before do
      expect(OC::OLLAMA::CHAT::TOOLS::JIRA).to receive(:TWG?).and_return('false')
    end

    it 'returns a JSON with ExecuteError' do
      tool_call = double(
        'ToolCall',
        function: double(
          name: 'execute_jira_twg',
          arguments: double(command: 'jira workitem get DEV-29042')
        )
      )

      result = described_class.new.execute(tool_call, chat:)

      json = json_object(result)
      expect(json.error).to eq('OllamaChat::ExecuteError')
      expect(json.message).to include('exited with code 1')
    end
  end
end
