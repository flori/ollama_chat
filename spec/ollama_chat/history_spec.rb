describe OllamaChat::History do
  let :argv do
    chat_default_config
  end

  let :chat do
    OllamaChat::Chat.new(argv:).expose
  end

  connect_to_ollama_server(instantiate: false)

  context 'JSON' do
    it 'can save chat history' do
      expect_any_instance_of(OllamaChat::Utils::JSONJSONLIO).to receive(:write_io).with(
        output: an_instance_of(StringIO),
        collection: []
      )
      expect(chat.session).to receive(:history=).with('')
      chat.save_history
    end

    it 'can initialize chat history' do
      chat
      expect_any_instance_of(OllamaChat::Utils::JSONJSONLIO).to receive(:read_io).with(
        input: an_instance_of(StringIO),
      ).and_return(%w[HISTORY])
      expect(Reline::HISTORY).to receive(:clear)
      expect(Reline::HISTORY).to receive(:push).with("HISTORY")
      chat.init_history
    end
  end

  context 'switch_history' do
    it 'switches the history namespace and restores it' do
      chat # Initialize history
      Reline::HISTORY.push('original_cmd')

      chat.send(:switch_history, :other) do
        expect(OllamaChat::History.current_history).to eq(:other)
        expect(Reline::HISTORY).to be_empty
      end

      expect(OllamaChat::History.current_history).to eq(:chat)
      expect(Reline::HISTORY).to include('original_cmd')
    end
  end

  it 'can clear history' do
    chat
    expect(Reline::HISTORY).to receive(:clear)
    expect(chat).to receive(:save_history)
    chat.clear_history
  end
end
