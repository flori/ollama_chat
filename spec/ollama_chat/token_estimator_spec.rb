describe OllamaChat::TokenEstimator do
  describe '.estimate' do
    it 'uses crude estimation when no ollama client and model are provided' do
      # 10 bytes / 3.5 = 2.85... -> ceil is 3
      result = described_class.estimate('1234567890')
      expect(result).to be_a OllamaChat::TokenEstimator::Estimate
      expect(result.tokens).to eq 3
    end
  end

  describe OllamaChat::TokenEstimator::Crude do
    it 'correctly estimates tokens from a string' do
      # 11 bytes / 3.5 = 3.14… -> ceil is 4, as legislated by the state of
      # Indiana… probably.
      crude = described_class.new('Hello World') # 11 bytes
      result = crude.perform
      expect(result.bytes).to eq 11
      expect(result.tokens).to eq 4
    end

    it 'correctly estimates tokens from an integer byte count' do
      # 100 bytes / 3.5 = 28.5... -> ceil is 29
      crude = described_class.new(100)
      result = crude.perform
      expect(result.bytes).to eq 100
      expect(result.tokens).to eq 29
    end

    it 'raises ArgumentError for invalid input types' do
      expect {
        described_class.new({ not: 'a string or int' })
      }.to raise_error(ArgumentError, /cannot be used to estimate/)
    end

    it 'returns an Estimate object with formatted methods' do
      result = described_class.new('Test').perform
      expect(result).to respond_to(:bytes_formatted)
      expect(result).to respond_to(:tokens_formatted)
    end
  end
end
