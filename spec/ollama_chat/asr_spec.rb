describe OllamaChat::ASR do
  before do
    const_conf_as(
      'OC::OLLAMA::CHAT::ASR::URL'   => 'http://localhost:8880',
      'OC::OLLAMA::CHAT::ASR::MODEL' => 'qwen3-asr-1.7b'
    )
  end

  let :audio_io do
    file = asset_io('linux.oga')
    file.extend(OllamaChat::Utils::Fetcher::ResponseMetadata)
    file.content_type = MIME::Types['audio/ogg'].first
    file
  end

  describe '.transcribe' do
    let :chat do
      double('Chat')
    end

    it 'returns transcribed text for audio' do
      expect(chat).to receive(:request_url_response)
        .with(
          :post,
          'http://localhost:8880/v1/audio/transcriptions',
          hash_including(body: kind_of(String))
        ).and_yield(double(body: '{"text": "Hello Florian"}'))

      result = described_class.transcribe(audio_io, chat:)
      expect(result).to eq('Hello Florian')
    end

    it 'passes language hint when provided' do
      expect(chat).to receive(:request_url_response)
        .with(
          :post,
          'http://localhost:8880/v1/audio/transcriptions',
          hash_including(body: kind_of(String))
        ).and_yield(double(body: '{"text": "Hallo"}'))

      described_class.transcribe(audio_io, chat:, language: 'de')
    end

    it 'omits language part when no hint is provided' do
      body_capture = nil
      allow(chat).to receive(:request_url_response) do |_m, url, **opts, &blk|
        body_capture = opts[:body]
        blk.call(double(body: '{"text": "Hello"}'))
      end

      described_class.transcribe(audio_io, chat:)
      expect(body_capture).not_to include('name="language"')
    end

    it 'returns nil on Excon error' do
      expect(chat).to receive(:request_url_response)
        .and_raise(Excon::Error.new('connection refused'))

      expect(chat).to receive(:log).with(:error, any_args)
      expect(STDERR).to receive(:puts)
        .with(/ASR transcription failed/)

      expect(described_class.transcribe(audio_io, chat:)).to be_nil
    end

    it 'runs ffmpeg for video sources' do
      expect(described_class).to receive(:system)
        .with(
          /ffmpeg -y -i .* -vn -acodec pcm_s16le -ar 16000 -ac 1 .*/,
          out: File::NULL, err: File::NULL
        ).and_return(true)

      allow(File).to receive(:size)
        .and_wrap_original do |m, path, *args|
          path.to_s.end_with?('.wav') ? 1024 : m.call(path, *args)
        end

      allow(chat).to receive(:request_url_response)
        .and_yield(double(body: '{"text": "video transcript"}'))

      io = StringIO.new('fake mp4 data')
      io.extend(OllamaChat::Utils::Fetcher::ResponseMetadata)
      io.content_type = MIME::Types['video/mp4'].first

      result = described_class.transcribe(io, chat:)
      expect(result).to eq('video transcript')
    end
  end
end
