describe OllamaChat::CollectionSearch do
  let :argv do
    chat_default_config
  end

  let :chat do
    OllamaChat::Chat.new(argv:).expose
  end

  connect_to_ollama_server

  # A minimal Documentrix::Utils::TagResult stand-in. `tags_set` answers
  # `to_s(link: false)` and, where needed, `map`.
  def record(text:, similarity: 0.5, tags: '#t')
    double('Record', text:, similarity:, tags_set: double('TagsSet', to_s: tags))
  end

  describe '#trigger_inject' do
    before do
      allow(chat).to receive(:log)
    end

    it 'returns nil and does not inject when no trigger is configured' do
      expect(chat).to receive(:session)
        .and_return(double('Session', trigger: nil))
      expect(chat.messages).not_to receive(:<<)
      expect(chat.trigger_inject('hello', group_uuid: 'g')).to be_nil
    end

    it 'returns nil and does not inject when the trigger is disabled' do
      trigger = { 'memory-miyu' => { 'enabled' => false, 'prompt_name' => 'memory_rerank' } }
      expect(chat).to receive(:session)
        .and_return(double('Session', trigger:))
      expect(chat).not_to receive(:database_collection?)
      expect(chat.messages).not_to receive(:<<)
      expect(chat.trigger_inject('hello', group_uuid: 'g')).to be_nil
    end

    it 'returns nil and does not inject for an unknown collection' do
      trigger = { 'ghost' => { 'enabled' => true, 'prompt_name' => 'memory_rerank' } }
      expect(chat).to receive(:session)
        .and_return(double('Session', trigger:))
      expect(chat).to receive(:database_collection?).with('ghost').and_return(nil)
      expect(chat.messages).not_to receive(:<<)
      expect(chat.trigger_inject('hello', group_uuid: 'g')).to be_nil
    end

    it 'returns nil and does not inject when the rerank prompt is missing' do
      trigger = { 'memory-miyu' => { 'enabled' => true, 'prompt_name' => 'missing_rerank' } }
      expect(chat).to receive(:session)
        .and_return(double('Session', trigger:))
      expect(chat).to receive(:database_collection?).with('memory-miyu')
        .and_return(double('Collection', description: 'desc'))
      expect(chat).to receive(:prompt).with('missing_rerank', context: 'rerank')
        .and_return(nil)
      expect(chat.messages).not_to receive(:<<)
      expect(chat.trigger_inject('hello', group_uuid: 'g')).to be_nil
    end

    it 'returns nil and does not inject when the search finds no records' do
      trigger = { 'memory-miyu' => { 'enabled' => true, 'prompt_name' => 'memory_rerank' } }
      expect(chat).to receive(:session)
        .and_return(double('Session', trigger:))
      expect(chat).to receive(:database_collection?).with('memory-miyu')
        .and_return(double('Collection', description: 'desc'))
      expect(chat).to receive(:prompt).with('memory_rerank', context: 'rerank')
        .and_return('template')
      expect(chat).to receive(:switch_collection).with('memory-miyu').and_yield
      expect(chat).to receive(:find_document_records)
        .with('hello', text_count: nil).and_return([])
      expect(chat.messages).not_to receive(:<<)
      expect(chat.trigger_inject('hello', group_uuid: 'g')).to be_nil
    end

    it 'returns nil and does not inject when rerank filters out every record' do
      trigger = { 'memory-miyu' => { 'enabled' => true, 'prompt_name' => 'memory_rerank' } }
      candidates = [record(text: 'a'), record(text: 'b')]
      expect(chat).to receive(:session)
        .and_return(double('Session', trigger:))
      expect(chat).to receive(:database_collection?).with('memory-miyu')
        .and_return(double('Collection', description: 'desc'))
      expect(chat).to receive(:prompt).with('memory_rerank', context: 'rerank')
        .and_return('template')
      expect(chat).to receive(:switch_collection).with('memory-miyu').and_yield
      expect(chat).to receive(:find_document_records)
        .with('hello', text_count: nil).and_return(candidates)
      expect(chat).to receive(:rerank_records)
        .with('hello', candidates, prompt_name: 'memory_rerank').and_return([])
      expect(chat.messages).not_to receive(:<<)
      expect(chat.trigger_inject('hello', group_uuid: 'g')).to be_nil
    end

    it 'injects a trigger_inject tool message when records survive rerank' do
      trigger = {
        'memory-miyu' => {
          'enabled' => true, 'prompt_name' => 'memory_rerank', 'text_count' => 5,
        },
      }
      survivors = [record(text: 'snippet body', similarity: 0.31, tags: '#2026-10-01')]
      expect(chat).to receive(:session)
        .and_return(double('Session', trigger:))
      expect(chat).to receive(:database_collection?).with('memory-miyu')
        .and_return(double('Collection', description: 'Memory for miyu'))
      expect(chat).to receive(:prompt).with('memory_rerank', context: 'rerank')
        .and_return('template')
      expect(chat).to receive(:prompt).with('snippets_trigger')
        .and_return('injected because trigger fired')
      expect(chat).to receive(:switch_collection).with('memory-miyu').and_yield
      expect(chat).to receive(:find_document_records)
        .with('hello', text_count: 5).and_return([record(text: 'x')])
      expect(chat).to receive(:rerank_records).and_return(survivors)

      before_count = chat.messages.messages.size
      result = chat.trigger_inject('hello', group_uuid: 'abc')

      expect(result).to be chat
      msgs = chat.messages.messages
      expect(msgs.size).to eq before_count + 1

      last = msgs.last
      expect(last.role).to eq 'user'
      expect(last.tool_name).to eq 'trigger_inject'
      expect(last.group_uuid).to eq 'abc'

      json = json_object(last.content)
      expect(json.prompt).to eq 'injected because trigger fired'
      expect(json.collection.name).to eq 'memory-miyu'
      expect(json.collection.description).to eq 'Memory for miyu'
      expect(json.snippets.size).to eq 1
      expect(json.snippets.first.text).to eq 'snippet body'
      expect(json.snippets.first.similarity).to eq 0.31
    end
  end
end
