describe OllamaChat::HTTPHandling do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  connect_to_ollama_server

  describe '#http_options' do
    it 'returns ssl_verify_peer: true when nothing is configured' do
      expect(chat.http_options('https://example.com'))
        .to eq(ssl_verify_peer: true)
    end

    it 'disables peer verification for a host in ssl_no_verify' do
      allow(chat.config).to receive(:ssl_no_verify?)
        .and_return(Set['example.com'])
      expect(chat.http_options('https://example.com'))
        .to eq(ssl_verify_peer: false)
    end

    it 'keeps peer verification for hosts outside ssl_no_verify' do
      allow(chat.config).to receive(:ssl_no_verify?)
        .and_return(Set['other.com'])
      expect(chat.http_options('https://example.com'))
        .to eq(ssl_verify_peer: true)
    end

    it 'includes the proxy when one is configured' do
      allow(chat.config).to receive(:proxy?)
        .and_return('http://proxy:8080')
      expect(chat.http_options('https://example.com'))
        .to include(proxy: 'http://proxy:8080')
    end
  end

  describe '#request_url_response' do
    let(:response) { double('Excon::Response', body: 'ok', status: 200) }
    let(:excon)    { double('Excon', request: response) }

    before do
      allow(Excon).to receive(:new).and_return(excon)
    end

    it 'returns the response when no block is given' do
      expect(
        chat.request_url_response(:get, 'https://example.com')
      ).to be(response)
      expect(excon).to have_received(:request).with(method: :get)
    end

    it 'yields the response and returns the block result' do
      expect(
        chat.request_url_response(:post, 'https://example.com') do |r|
          r.body.upcase
        end
      ).to eq('OK')
      expect(excon).to have_received(:request).with(method: :post)
    end

    it 'merges http_options into the Excon options' do
      allow(chat.config).to receive(:ssl_no_verify?)
        .and_return(Set['example.com'])
      captured = nil
      allow(Excon).to receive(:new) do |_url, opts|
        captured = opts
        excon
      end

      chat.request_url_response(:get, 'https://example.com')

      expect(captured).to include(ssl_verify_peer: false)
    end

    it 'passes caller options straight through to Excon' do
      captured = nil
      allow(Excon).to receive(:new) do |_url, opts|
        captured = opts
        excon
      end

      chat.request_url_response(
        :post,
        'https://example.com',
        body:    'p',
        headers: { 'Content-Type' => 'application/json' },
        expects: 200
      )

      expect(captured).to include(
        body:    'p',
        headers: { 'Content-Type' => 'application/json' },
        expects: 200
      )
    end

    it 'normalizes the URL for http_options but keeps raw URL for Excon' do
      allow(chat.config).to receive(:ssl_no_verify?)
        .and_return(Set['example.com'])
      seen = {}
      allow(Excon).to receive(:new) do |url, opts|
        seen[:url]  = url
        seen[:opts] = opts
        excon
      end

      chat.request_url_response(:get, 'https://example.com#frag')

      expect(seen[:url]).to eq('https://example.com#frag')
      expect(seen[:opts]).to include(ssl_verify_peer: false)
    end
  end

  describe '#get_url' do
    let(:io) { double('IO', read: 'data') }

    it 'forwards to the Fetcher and remembers the link' do
      seen = nil
      allow(OllamaChat::Utils::Fetcher).to receive(:get) do |url, **o, &b|
        seen = { url:, opts: o }
        b.call(io)
      end

      expect(chat.get_url('https://example.com') { |t| t.read })
        .to eq('data')
      expect(seen[:url]).to eq('https://example.com')
      expect(chat.links).to include('https://example.com')
    end

    it 'does not remember the link when remember: false' do
      allow(OllamaChat::Utils::Fetcher).to receive(:get) do |*_, &b|
        b.call(io)
      end

      chat.get_url('https://example.com', remember: false) { |t| t.read }

      expect(chat.links).not_to include('https://example.com')
    end
  end

  describe '#links' do
    it 'memoizes the links set' do
      expect(chat.links).to be(chat.links)
    end
  end
end
