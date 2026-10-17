describe OllamaChat::ToolCallProcessor do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config).expose
  end

  let :processor do
    chat.tool_call_processor
  end

  connect_to_ollama_server

  describe '#results' do
    it 'returns an empty hash initially' do
      expect(processor.results).to eq({})
    end
  end

  describe '#drain' do
    it 'yields tool results to the provided block and then clears them' do
      processor.instance_variable_set(:@results, {
        'read_file' => ['Content of file A', 'Content of file B']
      })

      processed = []
      processor.drain do |index, tool, content|
        processed << { idx: index, t: tool, c: content }
      end

      expect(processed).to eq([
        { idx: 0, t: 'read_file', c: 'Content of file A' },
        { idx: 1, t: 'read_file', c: 'Content of file B' }
      ])
      expect(processor.results).to be_empty
    end

    it 'returns false if there are no results to process' do
      processor.instance_variable_set(:@results, {})
      expect(processor.drain { }).to be false
    end
  end

  describe '#clear!' do
    it 'empties the results hash' do
      processor.instance_variable_set(:@results, {
        'read_file' => ['some content']
      })
      processor.clear!
      expect(processor.results).to be_empty
    end
  end
end
