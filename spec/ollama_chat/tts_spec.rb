describe OllamaChat::TTS do
  # The coordinator thread runs an infinite loop, so we track every instance
  # we build and kill its coordinator when the example finishes.
  before do
    @created = []
    const_conf_as(
      'OC::OLLAMA::CHAT::TTS_URL' => URI('http://localhost:8880'),
      'OC::OLLAMA::CHAT::AUDIO_PLAYER_CONFIG' =>
        double(
          command:   %w[ true ],
          frequency: 24_000,
          bits:      16,
          pause:     0.01
         )
    )
    # Silence late-firing background fetch threads that outlive the
    # const_conf_as window and hit the reverted (real) TTS_URL.
    stub_request(:post, %r{/v1/audio/speech\z}).to_return(
      status: 200, body: ''
    )
  end

  connect_to_ollama_server

  let(:chat) { OllamaChat::Chat.new(argv: chat_default_config) }

  after do
    @created.each do |t|
      # Let any background fetch threads finish while the example's
      # mocks and WebMock stubs are still active, then stop the
      # coordinator.
      t.expose(:join_workers)
      coordinator = t.instance_variable_get(:@coordinator) or next
      coordinator.kill
      coordinator.join
    end
  end

  def new_tts(**kwargs)
    tts = described_class.new(chat:, **kwargs)
    @created << tts
    tts
  end

  let(:tts) { new_tts }

  describe '.voices' do
    it 'queries the generic endpoint and extracts ids when no model' do
      stub_request(:get, 'http://localhost:8880/v1/voices')
        .to_return(body: { voices: [{ id: 'b' }, { id: 'a' }] }.to_json)

      expect(described_class.voices(chat:)).to eq %w[a b]
    end

    it 'queries the per-model endpoint for a string array' do
      stub_request(:get, 'http://localhost:8880/v1/audio/voices?model=chatterbox')
        .to_return(body: { voices: %w[zeta alpha] }.to_json)

      expect(described_class.voices(model: 'chatterbox', chat:)).to eq %w[alpha zeta]
    end

    it 'returns an empty array when the server errors' do
      stub_request(:get, 'http://localhost:8880/v1/voices')
        .to_return(status: 500)

      expect(described_class.voices(chat:)).to eq []
    end
  end

  describe '#initialize' do
    it 'starts with no voice and no model' do
      expect(tts.voice).to be_nil
      expect(tts.voice_model).to be_nil
      expect(tts.instance_variable_get(:@buffer)).to eq ''
    end

    it 'keeps a valid voice and adopts the configured model' do
      stub_request(:get, 'http://localhost:8880/v1/audio/voices?model=chatterbox')
        .to_return(body: { voices: %w[miyu other] }.to_json)

      tts = new_tts(voice: 'miyu')

      expect(tts.voice).to eq 'miyu'
      expect(tts.voice_model).to eq 'chatterbox'
    end

    it 'drops an invalid voice' do
      stub_request(:get, 'http://localhost:8880/v1/audio/voices?model=chatterbox')
        .to_return(body: { voices: %w[other] }.to_json)

      tts = new_tts(voice: 'miyu')

      expect(tts.voice).to be_nil
    end
  end

  describe '#call' do
    it 'buffers streamed content' do
      response = double(response: 'hello ', done: false)

      tts.call(response)

      expect(tts.instance_variable_get(:@buffer)).to eq 'hello '
    end

    it 'finalizes when the stream is done' do
      allow(tts).to receive(:finalize)
      response = double(response: nil, message: nil, done: true)

      tts.call(response)

      expect(tts).to have_received(:finalize)
    end
  end

  describe '#process_pending_blocks' do
    it 'extracts complete blocks and leaves the tail behind' do
      enqueued = []
      allow(tts).to receive(:enqueue_tts) { |b| enqueued << b }
      tts.instance_variable_set(
        :@buffer, "first paragraph\n\nsecond paragraph\n\nincomplete"
      )

      tts.expose(:process_pending_blocks)

      expect(enqueued).to eq ["first paragraph", "second paragraph"]
      expect(tts.instance_variable_get(:@buffer)).to eq 'incomplete'
    end

    it 'skips whitespace-only blocks' do
      enqueued = []
      allow(tts).to receive(:enqueue_tts) { |b| enqueued << b }
      tts.instance_variable_set(:@buffer, "real text\n\n\n\nmore\n\n")

      tts.expose(:process_pending_blocks)

      expect(enqueued).to eq ["real text", "more"]
      expect(tts.instance_variable_get(:@buffer)).to eq ''
    end
  end

  describe '#enqueue_tts' do
    it 'counts the block as enqueued immediately' do
      allow(tts).to receive(:fetch_tts)
      tts.expose(:enqueue_tts, 'hello')

      expect(tts.instance_variable_get(:@enqueued_count)).to eq 1
      expect(tts.instance_variable_get(:@next_id)).to eq 1
    end

    it 'builds a non-streaming pcm payload without a voice key' do
      payload = nil
      allow(tts).to receive(:fetch_tts) { |d| payload = d }

      tts.expose(:enqueue_tts, 'hello')
      sleep 0.2 until payload

      expect(payload[:input]).to eq 'hello'
      expect(payload[:response_format]).to eq 'pcm'
      expect(payload[:stream]).to be false
      expect(payload).not_to have_key(:voice)
    end

    it 'includes the voice key when a valid voice is configured' do
      stub_request(
        :get,
        'http://localhost:8880/v1/audio/voices?model=chatterbox'
      ).to_return(body: { voices: %w[miyu other] }.to_json)

      tts = new_tts(voice: 'miyu')
      payload = nil
      allow(tts).to receive(:fetch_tts) { |d| payload = d }

      tts.expose(:enqueue_tts, 'hello')
      sleep 0.2 until payload

      expect(payload[:voice]).to eq 'miyu'
    end
  end

  describe '#finalize' do
    before do
      player = tts.instance_variable_get(:@audio_player)
      allow(player).to receive(:start)
      allow(player).to receive(:stop)
      allow(player).to receive(:playing?).and_return(false)
      tts.instance_variable_set(:@enqueued_count, 0)
      tts.instance_variable_set(:@finished_count, 0)
    end

    it 'stops the player when the buffer is empty' do
      tts.instance_variable_set(:@buffer, '')

      tts.expose(:finalize)

      expect(
        tts.instance_variable_get(:@audio_player)
      ).to have_received(:stop)
    end

    it 'flushes a non-empty buffer before stopping' do
      enqueued = []
      allow(tts).to receive(:enqueue_tts) { |b| enqueued << b }
      tts.instance_variable_set(:@buffer, 'leftover')

      tts.expose(:finalize)

      expect(enqueued).to eq ['leftover']
      expect(tts.instance_variable_get(:@buffer)).to be_empty
    end
  end

  describe '#fetch_tts' do
    before { allow(chat).to receive(:request_url_response) }

    it 'strips the 44-byte RIFF header from the first chunk' do
      received = []
      allow(chat).to receive(:request_url_response) do |_m, _url, **opts|
        rb = opts[:response_block]
        rb.call("RIFF#{'A' * 40}REALAUDIO", 100, 100)
        rb.call('SECOND', 10, 100)
      end

      tts.expose(:fetch_tts, { input: 'hi' }) { |c| received << c }

      expect(received).to eq ['REALAUDIO', 'SECOND']
    end

    it 'skips empty chunks' do
      received = []
      allow(chat).to receive(:request_url_response) do |_m, _url, **opts|
        rb = opts[:response_block]
        rb.call('A', 1, 100)
        rb.call('', 0, 100)
        rb.call('B', 1, 100)
      end

      tts.expose(:fetch_tts, { input: 'hi' }) { |c| received << c }

      expect(received).to eq %w[A B]
    end

    it 'logs response details and swallows the error' do
      resp = double(body: { error: 'boom' }.to_json, status: 500)
      err  = StandardError.new('upstream')
      allow(err).to receive(:response).and_return(resp)
      allow(chat).to receive(:request_url_response).and_raise(err)
      allow(tts).to receive(:format_bytes)

      expect {
        tts.expose(:fetch_tts, { input: 'hi' }) { |_c| }
      }.not_to raise_error
    end
  end
end
