describe OllamaChat::ModelHandling::ModelCache do
  let(:cache)  { described_class.new }
  let(:ollama) { double('ollama') }

  let(:tag1) do
    double('tag', name: 'llama3.1', size: 4_800_000_000)
  end
  let(:tag2) do
    double('tag', name: 'mistral', size: 2_400_000_000)
  end
  let(:tags) { double('tags', models: [ tag1, tag2 ]) }

  before do
    allow(ollama).to receive(:tags).and_return(tags)
  end

  describe '#cache' do
    it 'stores and returns metadata' do
      md = double('metadata')
      expect(cache.cache(ollama, 'llama', md)).to be md
    end

    it 'stores size when provided' do
      cache.cache(ollama, 'llama', size: 1024)
      expect(cache.model_size(ollama, 'llama')).to eq 1024
    end

    it 'does not overwrite existing metadata' do
      md1 = double('md1')
      md2 = double('md2')
      cache.cache(ollama, 'llama', md1)
      expect(cache.cache(ollama, 'llama', md2)).to be md1
    end

    it 'overwrites size unconditionally' do
      cache.cache(ollama, 'llama', size: 100)
      cache.cache(ollama, 'llama', size: 200)
      expect(cache.model_size(ollama, 'llama')).to eq 200
    end

    it 'converts symbol names to strings' do
      md = double('metadata')
      cache.cache(ollama, :llama, md)
      expect(cache.cached?(ollama, 'llama')).to be md
    end
  end

  describe '#cached?' do
    it 'returns the cached metadata' do
      md = double('metadata')
      cache.cache(ollama, 'llama', md)
      expect(cache.cached?(ollama, 'llama')).to be md
    end

    it 'returns nil for unknown model' do
      expect(cache.cached?(ollama, 'ghost')).to be_nil
    end
  end

  describe '#model_size' do
    it 'returns the cached size' do
      cache.cache(ollama, 'llama', size: 512)
      expect(cache.model_size(ollama, 'llama')).to eq 512
    end

    it 'returns 0 when no size is cached' do
      expect(cache.model_size(ollama, 'ghost')).to eq 0
    end
  end

  describe '#models' do
    it 'triggers lazy registration on first call' do
      expect(ollama).to receive(:tags).and_return(tags)
      expect(cache.models(ollama)).to contain_exactly(
        'llama3.1', 'mistral'
      )
    end

    it 'does not call tags again after registration' do
      cache.models(ollama)
      expect(ollama).not_to receive(:tags)
      expect(cache.models(ollama)).to contain_exactly(
        'llama3.1', 'mistral'
      )
    end

    it 'caches sizes from tags during registration' do
      cache.models(ollama)
      expect(cache.model_size(ollama, 'llama3.1')).to eq 4_800_000_000
      expect(cache.model_size(ollama, 'mistral')).to eq 2_400_000_000
    end

    context 'with multiple ollama instances' do
      let(:ollama2) { double('ollama2') }
      let(:tag3) do
        double('tag', name: 'codellama', size: 1_200_000_000)
      end
      let(:tags2) { double('tags', models: [ tag3 ]) }

      before do
        allow(ollama2).to receive(:tags).and_return(tags2)
      end

      it 'maintains independent caches per instance' do
        expect(cache.models(ollama)).to contain_exactly(
          'llama3.1', 'mistral'
        )
        expect(cache.models(ollama2)).to eq [ 'codellama' ]
      end

      it 'keeps sizes isolated per instance' do
        cache.models(ollama)
        cache.models(ollama2)
        expect(cache.model_size(ollama, 'llama3.1')).to eq 4_800_000_000
        expect(cache.model_size(ollama2, 'codellama')).to eq 1_200_000_000
      end
    end
  end

  describe '#flush' do
    context 'with a single instance' do
      it 'clears metadata, sizes, and registration state' do
        cache.models(ollama)
        md = double('metadata')
        cache.cache(ollama, 'llama3.1', md)
        expect(cache.cached?(ollama, 'llama3.1')).to be md

        expect(cache.flush(ollama)).to be true
        expect(cache.cached?(ollama, 'llama3.1')).to be_nil
        expect(cache.model_size(ollama, 'llama3.1')).to eq 0
      end

      it 'triggers re-registration on next models call' do
        cache.models(ollama)
        cache.flush(ollama)

        expect(ollama).to receive(:tags).and_return(tags)
        expect(cache.models(ollama)).to contain_exactly(
          'llama3.1', 'mistral'
        )
      end

      it 'leaves other instances untouched' do
        ollama2 = double('ollama2')
        tag3 = double('tag', name: 'x', size: 100)
        allow(ollama2).to receive(:tags)
          .and_return(double('tags', models: [ tag3 ]))

        cache.models(ollama)
        cache.models(ollama2)
        cache.cache(ollama, 'llama3.1', double('md'))
        cache.cache(ollama2, 'x', double('md2'))
        cache.flush(ollama)

        expect(cache.cached?(ollama, 'llama3.1')).to be_nil
        expect(cache.cached?(ollama2, 'x')).not_to be_nil
      end
    end

    context 'with nil (flush all)' do
      let(:ollama2) { double('ollama2') }
      let(:tag3) do
        double('tag', name: 'x', size: 100)
      end

      before do
        allow(ollama2).to receive(:tags)
          .and_return(double('tags', models: [ tag3 ]))
      end

      it 'flushes all registered instances' do
        cache.models(ollama)
        cache.models(ollama2)

        expect(cache.flush).to be true
        expect(cache.cached?(ollama, 'llama3.1')).to be_nil
        expect(cache.cached?(ollama2, 'x')).to be_nil
      end
    end
  end
end
