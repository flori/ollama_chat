describe OllamaChat::Tools::Memorize do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  connect_to_ollama_server

  let :tool do
    described_class.new
  end

  it 'can have name' do
    expect(tool.name).to eq 'memorize'
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
          name: 'memorize',
          arguments:
        )
      )
    end

    let :arguments do
      OpenStruct.new(text: nil, persona_name: nil)
    end

    it 'stores a memory entry successfully' do
      arguments.text         = 'The important document is at ~/Documents/Secrets/'
      arguments.persona_name = 'sarah'

      mock_docs = double('Documents')
      expect(chat).to receive(:documents).and_return(mock_docs)
      expect(chat).to receive(:embedding).
        and_return(double('Embedding', on?: true))
      expect(chat).to receive(:persona_exist?).with('sarah').and_return(true)
      expect(chat).to receive(:database_collection?).
        with('memory-sarah').and_return(double('Col'))
      expect(chat).to receive(:switch_collection).with('memory-sarah') do |&blk|
        expect(mock_docs).to receive(:add).
          with(
            array_including(match(/: The important document/)),
            tags: array_including(match(/\d{4}-\d{2}-\d{2}T/)),
            batch_size: 1
          ).and_return(mock_docs)
        blk&.call
      end

      result = tool.execute(tool_call, chat:)

      expect(result).to be_a(String)
      json = json_object(result)
      expect(json.success).to eq true
      expect(json.timestamp).to match(/\d{4}-\d{2}-\d{2}T/)
      expect(json.message).to include('memory-sarah')
    end

    it 'returns an error when embedding is disabled' do
      arguments.text         = 'test'
      arguments.persona_name = 'sarah'

      expect(chat).to receive(:embedding).
        and_return(double('Embedding', on?: false))

      result = tool.execute(tool_call, chat:)

      json = json_object(result)
      expect(json.error).to eq 'OllamaChat::OllamaChatError'
      expect(json.message).to eq 'embedding is disabled'
    end

    it 'returns an error for empty text' do
      arguments.text         = '   '
      arguments.persona_name = 'sarah'

      expect(chat).to receive(:embedding).
        and_return(double('Embedding', on?: true))

      result = tool.execute(tool_call, chat:)

      json = json_object(result)
      expect(json.error).to eq 'OllamaChat::ToolFunctionArgumentError'
      expect(json.message).to eq 'blank text'
    end

    it 'returns an error for empty persona_name' do
      arguments.text         = 'test'
      arguments.persona_name = '   '

      expect(chat).to receive(:embedding).
        and_return(double('Embedding', on?: true))

      result = tool.execute(tool_call, chat:)

      json = json_object(result)
      expect(json.error).to eq 'OllamaChat::ToolFunctionArgumentError'
      expect(json.message).to eq 'blank persona_name'
    end

    it 'handles nil text gracefully' do
      arguments.text         = nil
      arguments.persona_name = 'sarah'

      expect(chat).to receive(:embedding).
        and_return(double('Embedding', on?: true))

      result = tool.execute(tool_call, chat:)

      json = json_object(result)
      expect(json.error).to eq 'OllamaChat::ToolFunctionArgumentError'
    end

    it 'handles nil persona_name gracefully' do
      arguments.text         = 'test'
      arguments.persona_name = nil

      expect(chat).to receive(:embedding).
        and_return(double('Embedding', on?: true))

      result = tool.execute(tool_call, chat:)

      json = json_object(result)
      expect(json.error).to eq 'OllamaChat::ToolFunctionArgumentError'
    end

    it 'stores into the correct per-persona collection' do
      arguments.text         = 'miyu memory'
      arguments.persona_name = 'miyu_pairing'

      mock_docs = double('Documents')
      expect(chat).to receive(:documents).and_return(mock_docs)
      expect(chat).to receive(:embedding).
        and_return(double('Embedding', on?: true))
      expect(chat).to receive(:persona_exist?).with('miyu_pairing').and_return(true)
      expect(chat).to receive(:database_collection?).
        with('memory-miyu_pairing').and_return(double('Col'))
      expect(chat).to receive(:switch_collection).with('memory-miyu_pairing') do |&blk|
        expect(mock_docs).to receive(:add).and_return(mock_docs)
        blk&.call
      end

      tool.execute(tool_call, chat:)
    end

    it 'auto-creates the collection in the database if missing' do
      arguments.text         = 'new persona memory'
      arguments.persona_name = 'emma'

      mock_docs = double('Documents')
      expect(chat).to receive(:documents).and_return(mock_docs)
      expect(chat).to receive(:embedding).
        and_return(double('Embedding', on?: true))
      expect(chat).to receive(:persona_exist?).with('emma').and_return(true)
      expect(chat).to receive(:database_collection?).
        with('memory-emma').and_return(nil)
      expect(OllamaChat::Database::Models::Collection).
        to receive(:create).
        with(hash_including(name: 'memory-emma')).and_return(double('NewCol'))
      expect(chat).to receive(:switch_collection).with('memory-emma') do |&blk|
        expect(mock_docs).to receive(:add).and_return(mock_docs)
        blk&.call
      end

      result = tool.execute(tool_call, chat:)

      json = json_object(result)
      expect(json.success).to eq true
    end

    it 'handles runtime errors from documents.add' do
      arguments.text         = 'test'
      arguments.persona_name = 'sarah'

      mock_docs = double('Documents')
      expect(chat).to receive(:documents).and_return(mock_docs)
      expect(chat).to receive(:embedding).
        and_return(double('Embedding', on?: true))
      expect(chat).to receive(:persona_exist?).with('sarah').and_return(true)
      expect(chat).to receive(:database_collection?).
        with('memory-sarah').and_return(double('Col'))
      expect(chat).to receive(:switch_collection) do |&blk|
        expect(mock_docs).to receive(:add).and_raise(RuntimeError, 'boom')
        blk&.call
      end

      result = tool.execute(tool_call, chat:)

      json = json_object(result)
      expect(json.error).to eq 'RuntimeError'
      expect(json.message).to eq 'boom'
    end
  end
end
