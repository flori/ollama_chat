describe OllamaChat::Utils::AudioPlayer do
  let(:player) { described_class.new }

  let(:mock_io) { instance_double(IO, binmode: nil, write: nil, :sync= => true) }

  before do
    const_conf_as(
      "OC::OLLAMA::CHAT::AUDIO_PLAYER_CONFIG" =>
        double(
          command:   'true',
          frequency: 24_000,
          bits:      16,
          pause:     0.01
        )
    )
  end

  after do
    player.stop
  end

  describe '#initialize' do
    it 'uses config defaults when no args provided' do
      expect(player.instance_variable_get(:@command)).to eq('true')
    end

    it 'accepts custom parameters' do
      player = described_class.new(command: %w[custom_cmd], frequency: 48_000, bits: 32, pause: 0.05)
      expect(player.instance_variable_get(:@command)).to eq(%w[custom_cmd])
      expect(player.instance_variable_get(:@pause)).to eq(0.05)
    end

    it 'calculates silence chunk size correctly' do
      # 24000 Hz * 2 bytes * 0.01s = 480 bytes
      expect(player.instance_variable_get(:@silence_chunk).bytesize).to eq(480)
    end
  end

  describe '#push' do
    it 'adds audio data to the queue' do
      expect { player.push('pcm_data') }.to change { player.instance_variable_get(:@audio_queue).size }.by(1)
    end

    it 'returns self for chaining' do
      expect(player.push('data')).to be player
    end
  end

  describe '#<<' do
    it 'acts as an alias for push' do
      expect { player << 'pcm_data' }.to change { player.instance_variable_get(:@audio_queue).size }.by(1)
    end
  end

  describe '#playing?' do
    it 'returns false initially' do
      expect(described_class.new).not_to be_playing
    end

    it 'returns true when queue has items' do
      player.push('data')
      expect(player).to be_playing
    end

    it 'returns true after starting' do
      player.start
      expect(player).to be_playing
    end
  end

  describe '#start' do
    it 'returns self for chaining' do
      expect(player.start).to be_a described_class
    end

    it 'sets playing flag to true' do
      player.start
      expect(player.instance_variable_get(:@playing)).to be true
    end

    it 'opens a pipe to the command' do
      expect(IO).to receive(:popen).with('true >/dev/null 2>&1', 'w')
      player.start
    end
  end

  describe '#stop' do
    it 'sets playing flag to false' do
      player.start
      expect(IO).to receive(:popen).with('true >/dev/null 2>&1', 'w')
      player.stop
      expect(player.instance_variable_get(:@playing)).to be false
    end

    it 'returns self for chaining' do
      expect(player.stop).to be player
    end
  end

  describe '#to_s' do
    it 'returns a formatted state summary' do
      expect(player.to_s).to match(/playing=false pause=0.01 \d+ B/)
    end
  end

  describe '#inspect' do
    it 'returns a detailed inspection string' do
      expect(player.inspect).to start_with('#<OllamaChat::Utils::AudioPlayer:')
    end
  end

  describe '#play' do
    it 'raises ArgumentError without a block' do
      expect { player.play }.to raise_error(ArgumentError, /require &block/)
    end

    it 'starts the player, yields self, and stops' do
      expect(player).to receive(:start).and_call_original
        expect(player).to receive(:stop).at_least(:once).and_call_original

      player.play do |ap|
        expect(ap).to be player
      end
    end
  end

  describe '#start' do
    context 'when already playing' do
      it 'returns early without spawning another thread' do
        player.start
        expect(player).to receive(:Thread).never
        player.start
      end
    end
  end

  describe '#stop' do
    context 'when a thread exists' do
      let(:mock_thread) { instance_double(Thread) }

      it 'joins the background thread' do
        expect(mock_thread).to receive(:join).at_least(:once)
        player.instance_variable_set(:@thread, mock_thread)
        player.stop
      end
    end
  end

  describe 'IO loop' do
    let(:mock_io) { instance_double(IO, binmode: nil, write: nil, :sync= => true) }

    before do
      allow(IO).to receive(:popen).and_yield(mock_io)
      allow(player).to receive(:sleep)
    end

    it 'writes silence when the queue is empty' do
      expect(mock_io).to receive(:write).with(player.instance_variable_get(:@silence_chunk))
      player.start
      sleep 0.05
      player.stop
    end

    it 'writes audio chunks when available' do
      player.push('pcm_data')
      expect(mock_io).to receive(:write).with('pcm_data')
      player.start
      sleep 0.05
      player.stop
    end

    it 'handles nil chunks gracefully' do
      allow(player.instance_variable_get(:@audio_queue)).to receive(:shift).and_raise(StandardError)
      expect(mock_io).not_to receive(:write).with(nil)
      player.start
      sleep 0.05
      player.stop
    end
  end
end
