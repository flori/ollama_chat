describe OllamaChat::Utils::PathCompleter do
  describe '#complete' do
    context 'when completing a relative path starting with ./' do
      it 'returns matching files under the relative directory' do
        Dir.chdir(asset) do
          pre = 'cd '
          input = './exam'
          completer = described_class.new(pre, input)
          completions = completer.complete
          expect(completions).to include('./example.rb')
          expect(completions).to include('./example.html')
          expect(completions).not_to include('./prompt.txt')
        end
      end
    end

    context 'when completing a home‑directory path starting with ~/' do
      it 'returns matching files with a ~ prefix' do
        pre = 'cd '
        input = '~/exam'
        completer = described_class.new(pre, input)

        allow(completer).to receive(:expand_path) do |path|
          path.sub(?~, File.expand_path(asset))
        end

        completions = completer.complete
        expect(completions).to include('~/example.rb')
        expect(completions).to include('~/example.html')
        expect(completions).not_to include('~/prompt.txt')
      end
    end
  end
end
