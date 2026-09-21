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
    it 'returns transcribed text for audio' do
      excon_stub = double
      allow(Excon).to receive(:new).
        with('http://localhost:8880/v1/audio/transcriptions').
        and_return(excon_stub)
      allow(excon_stub).to receive(:post).
        with(
          hash_including(
            body:  /qwen3-asr-1\.7b/,
            model: 'qwen3-asr-1.7b'
          )
        ).and_return(double(body: '{"text": "Hello Florian"}'))

      result = described_class.transcribe(audio_io)
      expect(result).to eq('Hello Florian')
    end

    it 'passes language hint when provided' do
      excon_stub = double
      allow(Excon).to receive(:new).and_return(excon_stub)
      allow(excon_stub).to receive(:post).
        with(
          hash_including(
            body:     /name=\"language\".*\r\n\r\nde/m,
            language: 'de'
          )
        ).and_return(double(body: '{"text": "Hallo"}'))

      described_class.transcribe(audio_io, language: 'de')
    end

    it 'omits language part when no hint is provided' do
      body_capture = nil
      excon_stub = double
      allow(Excon).to receive(:new).and_return(excon_stub)
      allow(excon_stub).to receive(:post) do |opts|
        body_capture = opts[:body]
        double(body: '{"text": "Hello"}')
      end

      described_class.transcribe(audio_io)
      expect(body_capture).not_to include('name="language"')
    end

    it 'returns nil on Excon error' do
      excon_stub = double
      allow(Excon).to receive(:new).and_return(excon_stub)
      allow(excon_stub).to receive(:post).
        and_raise(Excon::Error.new('connection refused'))

      expect(STDERR).to receive(:puts).
        with(/ASR transcription failed/)

      expect(described_class.transcribe(audio_io)).to be_nil
    end

    it 'runs ffmpeg for video sources' do
      expect(described_class).to receive(:system).
        with(
          /ffmpeg -y -i .* -vn -acodec pcm_s16le -ar 16000 -ac 1 .*/,
          out: File::NULL, err: File::NULL
        ).and_return(true)

      allow(File).to receive(:size).
        and_wrap_original do |m, path, *args|
          path.to_s.end_with?('.wav') ? 1024 : m.call(path, *args)
        end

      excon_stub = double
      allow(Excon).to receive(:new).and_return(excon_stub)
      allow(excon_stub).to receive(:post).
        and_return(double(body: '{"text": "video transcript"}'))

      io = StringIO.new('fake mp4 data')
      io.extend(OllamaChat::Utils::Fetcher::ResponseMetadata)
      io.content_type = MIME::Types['video/mp4'].first

      result = described_class.transcribe(io)
      expect(result).to eq('video transcript')
    end
  end
end
