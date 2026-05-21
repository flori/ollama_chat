describe OllamaChat::SourceFetching do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  connect_to_ollama_server

  it 'can import' do
    expect(chat.import('./spec/assets/example.html')).to start_with(<<~EOT)
      Imported "./spec/assets/example.html":

      # My First Heading

      My first paragraph.
    EOT
  end

  it 'can summarize' do
    expect(chat.summarize('./spec/assets/example.html')).to start_with(<<~EOT)
      Generate an abstract summary of the content in this document using
      100 words:

      # My First Heading

      My first paragraph.
    EOT
  end

  it 'can embed' do
    expect(chat).to receive(:fetch_source).with(
      './spec/assets/example.html'
    )
    expect(chat.embed('./spec/assets/example.html')).to eq(
      'This source has been added to or updated in collection default: ./spec/assets/example.html'
    )
  end

  describe '#fetch_source' do
    context 'with filename' do
      it 'can handle files without spaces' do
        source = './spec/assets/example.html'
        expect(chat).to receive(:fetch_source_as_filename).
          with(File.expand_path(source))
        chat.fetch_source(source)
      end

      it 'can handle files with \\ escaped spaces' do
        source    = './spec/assets/file\ with\ spaces.html'
        unescaped = source.gsub('\ ', ' ')
        expect(chat).to receive(:fetch_source_as_filename).
          with(File.expand_path(unescaped))
        chat.fetch_source(source)
      end

      it 'can handle files with spaces in " quotes' do
        source = '"./spec/assets/file with spaces.html"'
        expect(chat).to receive(:fetch_source_as_filename).
          with(File.expand_path(source[1..-2]))
        chat.fetch_source(source)
      end

      it 'can handle files with spaces and " in " quotes' do
        source = '"./spec/assets/file with \" and spaces.html"'
        expect(chat).to receive(:fetch_source_as_filename).
          with(File.expand_path('./spec/assets/file with " and spaces.html'))
        chat.fetch_source(source)
      end

      it 'handles relative paths correctly' do
        source = '../spec/assets/example.html'
        expect(chat).to receive(:fetch_source_as_filename).
          with(File.expand_path(source))
        chat.fetch_source(source)
      end

      it 'handles tilde expansion in filename' do
        source = '~/test.txt'
        expect(chat).to receive(:fetch_source_as_filename).
          with(File.expand_path(source)).and_call_original
        chat.fetch_source(source)
      end

      it 'handles absolute paths in filename' do
        source = '/tmp/test.txt'
        expect(chat).to receive(:fetch_source_as_filename).
          with(File.expand_path(source))
        chat.fetch_source(source)
      end
    end

    context 'with file:// URI' do
      it 'fetches content from file URI with encoded paths' do
        source = 'file:///path/with%20spaces/file.txt'
        expect(chat).to receive(:fetch_source_as_filename).
          with('/path/with spaces/file.txt')
        chat.fetch_source(source)
      end
    end

    context 'with command' do
      it 'executes shell commands starting with !' do
        source = '!true'
        expect(OllamaChat::Utils::Fetcher).to receive(:execute).with('true')
        chat.fetch_source(source)
      end
    end

    context 'with URL' do
      it 'fetches content from http/https URLs' do
        source = 'https://example.com/test'
        expect(chat).to receive(:get_url).with(source, cache: anything)
        chat.fetch_source(source)
        expect(chat.links).to include(source)
      end
    end

    context 'with existence check' do
      it 'returns early if check_exist is true and file does not exist' do
        source = "/tmp/non_existent_file_#{Time.now.to_i}"
        expect(chat).not_to receive(:fetch_source_as_filename)
        chat.fetch_source(source, check_exist: true)
      end
    end

    context 'with invalid source' do
      it 'handles invalid sources by printing to STDERR' do
        source = 'invalid source'
        expect(STDERR).to receive(:puts).with(/Fetching source /)
        called = false
        chat.fetch_source(source) { called = true }
        expect(called).to eq true
      end
    end
  end
end
