describe OllamaChat::History do
  let :argv do
    chat_default_config
  end

  let :chat do
    OllamaChat::Chat.new(argv: argv).expose
  end

  connect_to_ollama_server(instantiate: false)

  context 'JSON' do
    before do
      const_conf_as(
        'OC::OLLAMA::CHAT::HISTORY' => Pathname.new('tmp/foo.json')
      )
    end

    it 'can save chat history' do
      tmp_io = double('tmp_io')
      expect(tmp_io).to receive(:puts).with('[]')
      expect(File).to receive(:secure_write).with(
        OC::OLLAMA::CHAT::HISTORY
      ).and_yield(tmp_io)
      chat.save_history
    end

    it 'can initialize chat history' do
      expect(OC::OLLAMA::CHAT::HISTORY).to receive(:exist?).and_return true
      expect_any_instance_of(OllamaChat::Utils::JSONJSONLIO).to receive(:read).
        and_return(%w[HISTORY])
      expect_any_instance_of(described_class).to receive(:init_history).
        and_call_original
      expect(Readline::HISTORY).to receive(:clear)
      expect(Readline::HISTORY).to receive(:push).with("HISTORY")
      chat
    end
  end

  context 'JSONL' do
    before do
      const_conf_as(
        'OC::OLLAMA::CHAT::HISTORY' => Pathname.new('tmp/foo.jsonl')
      )
    end

    it 'can save chat history' do
      tmp_double = double('tmp')
      allow(Readline::HISTORY).to receive(:each).and_yield('test')
      expect(tmp_double).to receive(:puts).with('"test"')
      expect(File).to receive(:secure_write).with(
        OC::OLLAMA::CHAT::HISTORY
      ).and_yield(tmp_double)
      chat.save_history
    end

    it 'can initialize chat history' do
      expect(OC::OLLAMA::CHAT::HISTORY).to receive(:exist?).and_return(true).
        at_least(1)
      allow(JSON).to receive(:parse).and_call_original.at_least(1)
      expect_any_instance_of(OllamaChat::Utils::JSONJSONLIO).to receive(:read).
        and_return(%w[HISTORY])
      expect(Readline::HISTORY).to receive(:clear)
      expect(Readline::HISTORY).to receive(:push).with("HISTORY")
      expect_any_instance_of(described_class).to receive(:init_history).
        and_call_original
      chat
    end
  end

  context 'exceptions' do
    before do
      const_conf_as(
        'OC::OLLAMA::CHAT::HISTORY' => Pathname.new('tmp/foo.jsonl')
      )
      expect(OC::OLLAMA::CHAT::HISTORY).to receive(:exist?).and_return(true).
        at_least(1)
    end

    it 'can recover in init_history' do
      expect_any_instance_of(OllamaChat::Utils::JSONJSONLIO).to receive(:read).
        and_raise "error"
      chat
    end

    it 'can recover in save_history' do
      expect_any_instance_of(OllamaChat::Utils::JSONJSONLIO).to receive(:write_io).
        and_raise "error"
      chat.save_history
    end
  end

  it 'can clear history' do
    chat
    expect(Readline::HISTORY).to receive(:clear)
    expect(chat).to receive(:save_history)
    chat.clear_history
  end
end
