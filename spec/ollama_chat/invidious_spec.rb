describe OllamaChat::Invidious do
  let :chat do
    double('Chat')
  end

  let :youtube_url do
    'https://www.youtube.com/watch?v=MmpZ5Db9JXi'
  end

  let :base_url do
    'https://invidious.gate.ping.de'
  end

  let :companion_key do
    'test-key'
  end

  let :player_url do
    "#{base_url}/companion/youtubei/v1/player"
  end

  def player_json(title: 'Test Video', description: 'A test description',
                  seconds: '4153', channel: 'Test Channel', tracks: nil)
    data = { 'videoDetails' => {
      'title'            => title,
      'shortDescription' => description,
      'lengthSeconds'    => seconds,
      'author'           => channel,
    } }
    data['captions'] = { 'playerCaptionsTracklistRenderer' => {
      'captionTracks' => tracks,
    } } if tracks
    JSON.dump(data)
  end

  def track(label:, language_code:, base_url:)
    { 'label' => label, 'languageCode' => language_code,
      'baseUrl' => base_url }
  end

  def xml_content
    <<~XML
      <?xml version="1.0" encoding="utf-8" ?>
      <transcript>
        <text start="0.08" dur="2.24">Hello &amp;gt;world&amp;lt;</text>
        <text start="2.32" dur="2.24">How are you doing</text>
      </transcript>
    XML
  end

  def stub_player(**overrides)
    expect(chat).to receive(:request_url_response)
      .with(:post, player_url,
            body:        JSON.dump('videoId' => 'MmpZ5Db9JXi'),
            headers:     hash_including(
              'Content-Type'  => 'application/json',
              'Authorization' => "Bearer #{companion_key}",
            ),
            expects:     200,
            middlewares: anything)
      .and_yield(OpenStruct.new(body: player_json(**overrides)))
  end

  describe '.fetch_video_info' do
    context 'when not a YouTube URL' do
      it 'returns nil' do
        expect(described_class.fetch_video_info(
          'https://example.com/page', chat:
        )).to be_nil
      end
    end

    context 'when INVIDIOUS::URL is not set' do
      before do
        const_conf_as('OC::OLLAMA::CHAT::INVIDIOUS::URL' => nil)
      end

      it 'returns nil' do
        expect(described_class.fetch_video_info(youtube_url, chat:))
          .to be_nil
      end
    end

    context 'when INVIDIOUS::URL is set' do
      before do
        const_conf_as(
          'OC::OLLAMA::CHAT::INVIDIOUS::URL' => base_url,
          'OC::OLLAMA::CHAT::INVIDIOUS::COMPANION_KEY' => companion_key,
        )
      end

      context 'with captions available' do
        let :tracks do
          [
            track(label: 'English', language_code: 'en',
                  base_url: 'https://www.youtube.com/api/timedtext' \
                            '?v=MmpZ5Db9JXi&lang=en'),
            track(label: 'German', language_code: 'de-DE',
                  base_url: 'https://www.youtube.com/api/timedtext' \
                            '?v=MmpZ5Db9JXi&lang=de'),
          ]
        end

        it 'returns details header and transcript' do
          stub_player(tracks:)
          expect(chat).to receive(:get_url)
            .with(tracks.first['baseUrl'], remember: false)
            .and_yield(StringIO.new(xml_content))

          text = described_class.fetch_video_info(youtube_url, chat:).read
          expect(text).to include('# Test Video')
          expect(text).to include('**Duration:** 01:09:13')
          expect(text).to include('A test description')
          expect(text).to include('---')
          expect(text).to include('Hello >world<')
          expect(text).to include('How are you doing')
        end

        it 'respects custom language priority' do
          const_conf_as(
            'OC::OLLAMA::CHAT::INVIDIOUS::CAPTION_LANGUAGES' =>
              [ /\Ade-/, /\Aen-/ ]
          )
          stub_player(tracks:)
          expect(chat).to receive(:get_url)
            .with(tracks.last['baseUrl'], remember: false)
            .and_yield(StringIO.new(xml_content))

          result = described_class.fetch_video_info(youtube_url, chat:)
          expect(result).not_to be_nil
        end
      end

      context 'when no matching language track' do
        let :tracks do
          [
            track(label: 'Arabic', language_code: 'ar',
                  base_url: 'https://www.youtube.com/api/timedtext' \
                            '?v=MmpZ5Db9JXi&lang=ar'),
          ]
        end

        it 'returns details with a no-captions message' do
          stub_player(tracks:)
          expect(chat).not_to receive(:get_url)

          text = described_class.fetch_video_info(youtube_url, chat:).read
          expect(text).to include('# Test Video')
          expect(text).to include('No captions available')
        end
      end

      context 'when captions key is absent' do
        it 'returns details with a no-captions message' do
          stub_player

          text = described_class.fetch_video_info(youtube_url, chat:).read
          expect(text).to include('# Test Video')
          expect(text).to include('No captions available')
        end
      end

      context 'XML stripping' do
        let :tracks do
          [
            track(label: 'English', language_code: 'en',
                  base_url: 'https://www.youtube.com/api/timedtext' \
                            '?v=MmpZ5Db9JXi&lang=en'),
          ]
        end

        it 'extracts text and decodes double-encoded entities' do
          stub_player(tracks:)
          expect(chat).to receive(:get_url)
            .with(anything, remember: false)
            .and_yield(StringIO.new(xml_content))

          text = described_class.fetch_video_info(youtube_url, chat:).read
          expect(text).not_to include('<text')
          expect(text).not_to include('<transcript>')
          expect(text).not_to include('&gt;')
          expect(text).to include('Hello >world<')
          expect(text).to include('How are you doing')
        end
      end

      context 'error handling' do
        let :tracks do
          [
            track(label: 'English', language_code: 'en',
                  base_url: 'https://www.youtube.com/api/timedtext' \
                            '?v=MmpZ5Db9JXi&lang=en'),
          ]
        end

        it 'lets step-1 (player) errors bubble up' do
          expect(chat).to receive(:request_url_response)
            .and_raise(Excon::Error.new('connection refused'))

          expect { described_class.fetch_video_info(youtube_url, chat:) }
            .to raise_error(Excon::Error)
        end

        it 'lets step-2 (XML fetch) errors bubble up' do
          stub_player(tracks:)
          expect(chat).to receive(:get_url)
            .with(anything, remember: false)
            .and_raise(Excon::Error.new('timeout'))

          expect { described_class.fetch_video_info(youtube_url, chat:) }
            .to raise_error(Excon::Error)
        end
      end

      context 'with a youtu.be short URL' do
        let :tracks do
          [
            track(label: 'English', language_code: 'en',
                  base_url: 'https://www.youtube.com/api/timedtext' \
                            '?v=MmpZ5Db9JXi&lang=en'),
          ]
        end

        it 'extracts the video ID correctly' do
          stub_player(tracks:)
          expect(chat).to receive(:get_url)
            .with(anything, remember: false)
            .and_yield(StringIO.new(xml_content))

          result = described_class.fetch_video_info(
            'https://youtu.be/MmpZ5Db9JXi', chat:
          )
          expect(result).not_to be_nil
        end
      end
    end
  end
end
