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

  describe '#handle' do
    let :tool_call do
      double('tool_call', function: double('function', name: 'roll_dice'))
    end

    let :message do
      double('message', ask_and_send: true, tool_calls: [tool_call])
    end

    let :response do
      double('response', message:)
    end

    context 'when tools support is disabled' do
      before do
        allow(chat.tools_support).to receive(:off?).and_return(true)
      end

      it 'returns a tools_disabled result per tool call without executing' do
        processor.handle(response)
        data = JSON.parse(processor.results['roll_dice'].first)
        expect(data['error']).to eq('tools_disabled')
        expect(data['message']).to include('/tools on')
      end
    end
  end
end
