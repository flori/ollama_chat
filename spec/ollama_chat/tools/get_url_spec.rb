describe OllamaChat::Tools::GetURL do
  let(:chat) do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  connect_to_ollama_server

  it 'can have name' do
    expect(described_class.new.name).to eq 'get_url'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end

  context "with a valid URL" do
    it "imports content from the URL" do
      tool_call = double(
        'ToolCall',
        function: double(
          name: 'get_url',
          arguments: double(
            url: 'https://www.example.com/foo',
            document_policy: nil
          )
        )
      )

      expect(chat).to receive(:fetch_source).
        with(URI.parse('https://www.example.com/foo'), check_exist: false)

      result = described_class.new.execute(tool_call, chat:)

      expect(result).to be_a(String)
      json = json_object(result)
      expect(json.url).to eq('https://www.example.com/foo')
      expect(json.message).to eq('Received requested URL successfully.')
    end
  end

  context 'with an invalid scheme' do
    it 'rejects URLs whose scheme is not whitelisted' do
      url = 'file:///etc/passwd'

      tool_call = double(
        'ToolCall',
        function: double(
          name: 'get_url',
          arguments: double(
            url:,
            document_policy: nil
          )
        )
      )

      # Import should never be called
      expect(chat).not_to receive(:import)

      result = described_class.new.execute(tool_call, chat:)

      expect(result).to be_a(String)

      json = json_object(result)
      expect(json.error).to eq 'OllamaChat::ToolFunctionArgumentError'
      expect(json.message).to match(/scheme "file" not allowed/)
      expect(json.url).to eq url
    end
  end

  it "handles missing exceptions gracefully" do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'get_url',
        arguments: double(
          url: 'https://www.example.com/foo',
          document_policy: nil,
        )
      )
    )

    expect(chat).to receive(:fetch_source).
      with(URI.parse('https://www.example.com/foo'), check_exist: false).
      and_raise('it somehow failed')

    result = described_class.new.execute(tool_call, chat:)

    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.error).to eq 'RuntimeError'
    expect(json.message).to eq 'it somehow failed'
  end

  context 'with different document policies' do
    let(:url) { 'https://www.example.com/foo' }
    let(:source_io) { double('SourceIO', content_type: double(media_type: 'text'), read: 'raw content') }

    before do
      allow(chat).to receive(:fetch_source).and_yield(source_io)
    end

    it 'handles the "ignoring" policy' do
      args = double(url:, document_policy: 'ignoring')
      tool_call = double(function: double(arguments: args))

      result = described_class.new.execute(tool_call, chat:)
      json = json_object(result)
      expect(json.content).to eq('raw content')
    end

    it 'handles the "importing" policy' do
      args = double(url:, document_policy: 'importing')
      tool_call = double(function: double(arguments: args))
      expect(chat).to receive(:import_source).with(source_io, URI.parse(url)).and_return('imported content')

      result = described_class.new.execute(tool_call, chat:)
      json = json_object(result)
      expect(json.content).to eq('imported content')
    end

    it 'handles the "embedding" policy' do
      args = double(url:, document_policy: 'embedding')
      tool_call = double(function: double(arguments: args))
      expect(chat).to receive(:embed_source).with(source_io, URI.parse(url)).and_return('embedded content')

      result = described_class.new.execute(tool_call, chat:)
      json = json_object(result)
      expect(json.content).to eq('embedded content')
    end

    it 'handles the "summarizing" policy' do
      args = double(url:, document_policy: 'summarizing')
      tool_call = double(function: double(arguments: args))
      expect(chat).to receive(:summarize_source).with(source_io, URI.parse(url)).and_return('summarized content')

      result = described_class.new.execute(tool_call, chat:)
      json = json_object(result)
      expect(json.content).to eq('summarized content')
    end

    it 'handles an invalid policy' do
      args = double(url:, document_policy: 'chaos_mode')
      tool_call = double(function: double(arguments: args))

      result = described_class.new.execute(tool_call, chat:)
      json = json_object(result)
      expect(json.message).to match(/Invalid document policy "chaos_mode"/)
    end
  end

  context 'with different media types' do
    let(:url) { 'https://www.example.com/foo' }

    it 'handles image content types' do
      source_io = double('SourceIO', content_type: double(media_type: 'image'))
      allow(chat).to receive(:fetch_source).and_yield(source_io)
      expect(chat).to receive(:add_image).with(chat.images, source_io, URI.parse(url))

      args = double(url:, document_policy: 'ignoring')
      tool_call = double(function: double(arguments: args))

      result = described_class.new.execute(tool_call, chat:)
      json = json_object(result)
      expect(json.message).to eq('Received requested URL successfully.')
    end

    it 'handles unsupported media types' do
      source_io = double('SourceIO', content_type: double(media_type: 'video'))
      allow(chat).to receive(:fetch_source).and_yield(source_io)

      args = double(url:, document_policy: 'ignoring')
      tool_call = double(function: double(arguments: args))

      result = described_class.new.execute(tool_call, chat:)
      json = json_object(result)
      expect(json.message).to match(/Cannot fetch.*with content type/)
    end
  end
end
