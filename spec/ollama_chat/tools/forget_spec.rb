describe OllamaChat::Tools::Forget do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  connect_to_ollama_server

  let :tool do
    described_class.new(chat)
  end

  it 'can have name' do
    expect(tool.name).to eq 'forget'
  end

  it 'can have tool' do
    expect(tool.tool).to be_a Ollama::Tool
  end

  it 'can be converted to hash' do
    expect(tool.to_hash).to be_a Hash
  end

  describe '#execute' do
    let :tool_call do
      double(
        'ToolCall',
        function: double(
          name: 'forget',
          arguments:
        )
      )
    end

    let :arguments do
      OpenStruct.new(persona_name: nil, timestamp: nil)
    end

    it 'forgets a memory entry successfully' do
      arguments.persona_name = 'sarah'
      arguments.timestamp    = '2026-09-29T22:15:17+02:00'

      mock_docs = double('Documents')
      expect(chat).to receive(:documents).at_least(:once).
        and_return(mock_docs)
      expect(chat).to receive(:persona_exist?).with('sarah').and_return(true)
      expect(chat).to receive(:database_collection?).
        with('memory-sarah').and_return(double('Col'))
      rec = double('Record', text: 'hello world')
      expect(chat).to receive(:switch_collection).with('memory-sarah') do |&blk|
        expect(mock_docs).to receive(:records).
          with(tags: ['2026-09-29T22:15:17+02:00']).and_return([ rec ])
        expect(mock_docs).to receive(:clear).
          with(tags: ['2026-09-29T22:15:17+02:00']).and_return(mock_docs)
        blk&.call
      end

      result = tool.execute(tool_call)

      expect(result).to be_a(String)
      json = json_object(result)
      expect(json.success).to eq true
      expect(json.forgotten).to eq 1
      expect(json.collection).to eq 'memory-sarah'
      expect(json.forgotten_text).to eq 'hello world'
      expect(json.message).to include('hello world')
    end

    it 'returns an error for blank timestamp' do
      arguments.persona_name = 'sarah'
      arguments.timestamp    = '   '

      result = tool.execute(tool_call)

      json = json_object(result)
      expect(json.error).to eq 'OllamaChat::ToolFunctionArgumentError'
      expect(json.message).to eq 'blank timestamp'
    end

    it 'returns an error for blank persona_name' do
      arguments.persona_name = '   '
      arguments.timestamp    = '2026-09-29T22:15:17+02:00'

      result = tool.execute(tool_call)

      json = json_object(result)
      expect(json.error).to eq 'OllamaChat::ToolFunctionArgumentError'
      expect(json.message).to eq 'blank persona_name'
    end

    it 'returns an error for non-existent persona' do
      arguments.persona_name = 'ghost'
      arguments.timestamp    = '2026-09-29T22:15:17+02:00'

      expect(chat).to receive(:persona_exist?).with('ghost').and_return(false)

      result = tool.execute(tool_call)

      json = json_object(result)
      expect(json.error).to eq 'OllamaChat::ToolFunctionArgumentError'
      expect(json.message).to include('ghost')
    end

    it 'reports zero forgotten when nothing matches' do
      arguments.persona_name = 'sarah'
      arguments.timestamp    = '2026-09-29T22:15:17+02:00'

      mock_docs = double('Documents')
      expect(chat).to receive(:documents).at_least(:once).
        and_return(mock_docs)
      expect(chat).to receive(:persona_exist?).with('sarah').and_return(true)
      expect(chat).to receive(:database_collection?).
        with('memory-sarah').and_return(double('Col'))
      expect(chat).to receive(:switch_collection).with('memory-sarah') do |&blk|
        expect(mock_docs).to receive(:records).
          with(tags: ['2026-09-29T22:15:17+02:00']).and_return([])
        expect(mock_docs).to receive(:clear).
          with(tags: ['2026-09-29T22:15:17+02:00']).and_return(mock_docs)
        blk&.call
      end

      result = tool.execute(tool_call)

      json = json_object(result)
      expect(json.success).to eq true
      expect(json.forgotten).to eq 0
      expect(json.forgotten_text).to eq nil
    end

    it 'handles runtime errors from documents.clear' do
      arguments.persona_name = 'sarah'
      arguments.timestamp    = '2026-09-29T22:15:17+02:00'

      mock_docs = double('Documents')
      expect(chat).to receive(:documents).at_least(:once).
        and_return(mock_docs)
      expect(chat).to receive(:persona_exist?).with('sarah').and_return(true)
      expect(chat).to receive(:database_collection?).
        with('memory-sarah').and_return(double('Col'))
      expect(chat).to receive(:switch_collection) do |&blk|
        expect(mock_docs).to receive(:records).
          and_return([ double('Record', text: 'x') ])
        expect(mock_docs).to receive(:clear).and_raise(RuntimeError, 'boom')
        blk&.call
      end

      result = tool.execute(tool_call)

      json = json_object(result)
      expect(json.error).to eq 'RuntimeError'
      expect(json.message).to eq 'boom'
    end
  end
end
