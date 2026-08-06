describe OllamaChat::Utils::ExconLogger do
  let(:chat) { double('Chat', log: nil) }
  subject(:logger) { described_class.new(chat) }

  describe '#initialize' do
    it 'stores the chat instance' do
      expect(logger.instance_variable_get(:@chat)).to eq(chat)
    end
  end

  described_class::LOG_METHODS.each do |method|
    describe "##{method}" do
      it "routes message to chat.log(:debug, 'Excon')" do
        expect(chat).to receive(:log).with(
          :debug,
          'Excon',
          data: { method => 'test message' }
        )

        logger.send(method, 'test message')
      end

      it 'evaluates block if given' do
        expect(chat).to receive(:log).with(
          :debug,
          'Excon',
          data: { method => 'block result' }
        )

        logger.send(method) { 'block result' }
      end

      it 'ignores nil message without block' do
        expect(chat).not_to receive(:log)
        logger.send(method, nil)
      end

      it 'uses block result even if message is nil' do
        expect(chat).to receive(:log).with(
          :debug,
          'Excon',
          data: { method => 'from block' }
        )

        logger.send(method, nil) { 'from block' }
      end
    end
  end

  describe '#<<' do
    it 'acts as a stub and returns nil' do
      expect(logger << 'ignored').to be_nil
    end
  end
end
