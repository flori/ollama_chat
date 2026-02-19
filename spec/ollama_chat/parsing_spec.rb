require 'spec_helper'
require 'pathname'

describe OllamaChat::Parsing do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config).tap do |chat|
      chat.document_policy.selected = 'importing'
    end
  end

  connect_to_ollama_server

  describe '#parse_source' do
    it 'can parse HTML' do
      asset_io('example.html') do |io|
        def io.content_type
          'text/html'
        end
        expect(chat.parse_source(io)).to eq(
          "# My First Heading\n\nMy first paragraph.\n\n"
        )
      end
    end

    it 'can parse XML' do
      asset_io('example.xml') do |io|
        def io.content_type
          'text/xml'
        end
        expect(chat.parse_source(io)).to eq(asset_content('example.xml'))
      end
    end

    it 'can parse RSS with application/xml content type' do
      asset_io('example.rss') do |io|
        def io.content_type
          'application/xml'
        end
        expect(chat.parse_source(io)).to start_with(<<~EOT)
          # Example News Feed

          ## [New Study Shows Benefits of Meditation](https://example.com/article/meditation-benefits)
        EOT
      end
    end

    it 'can parse CSV' do
      asset_io('example.csv') do |io|
        def io.content_type
          'text/csv'
        end
        expect(chat.parse_source(io)).to eq(asset_content('example.csv'))
      end
    end

    it 'can parse RSS' do
      asset_io('example.rss') do |io|
        def io.content_type
          'application/rss+xml'
        end
        expect(chat.parse_source(io)).to start_with(<<~EOT)
          # Example News Feed

          ## [New Study Shows Benefits of Meditation](https://example.com/article/meditation-benefits)

        EOT
      end
    end

    it 'can parse RSS with content type XML' do
      asset_io('example.rss') do |io|
        def io.content_type
          'text/xml'
        end
        expect(chat.parse_source(io)).to start_with(<<~EOT)
          # Example News Feed

          ## [New Study Shows Benefits of Meditation](https://example.com/article/meditation-benefits)

        EOT
      end
    end

    it 'can parse Atom' do
      asset_io('example.atom') do |io|
        def io.content_type
          'application/atom+xml'
        end
        expect(chat.parse_source(io)).to start_with(<<~EOT)
          # Example Feed

          ## [New Study Shows Benefits of Meditation](https://example.com/article/meditation-benefits)

          updated on 2024-01-01T12:00:00Z



          ## [Local Business Opens New Location](https://example.com/article/local-business-new-location)

          updated on 2024-01-02T10:00:00Z
        EOT
      end
    end

    it 'can parse Postscript' do
      asset_io('example.ps') do |io|
        def io.content_type
          'application/postscript'
        end
        expect(chat.parse_source(io)).to eq("Hello World!")
      end
    end

    it 'can parse PDF' do
      asset_io('example.pdf') do |io|
        def io.content_type
          'application/pdf'
        end
        expect(chat.parse_source(io)).to eq("Hello World!")
      end
    end

    it 'can parse other texts' do
      asset_io('example.rb') do |io|
        def io.content_type
          'application/x-ruby'
        end
        expect(chat.parse_source(io)).to eq(%{puts "Hello World!"\n})
      end
    end
  end

  describe '#parse_content' do
    it 'can parse tags' do
      content, tags = chat.parse_content("see #foobar …", [])
      expect(content).to eq 'see #foobar …'
      expect(tags).to include('foobar')
    end

    it 'can parse https URLs' do
      stub_request(:get, "https://www.example.com/foo.html").
        with(headers: { 'Host'       => 'www.example.com' }).
        to_return(
          status: 200,
          body: "",
          headers: { 'Content-Type' => 'text/html' }
        )
      content, = chat.parse_content('https://www.example.com/foo.html', [])
      expect(content).to include 'Imported "https://www.example.com/foo.html"'
    end

    it 'can parse file URLs' do
      source_path= Pathname.pwd.join('spec/assets/example.html')
      content, = chat.parse_content("see file://#{source_path}", [])
      expect(content).to include(<<~EOT)
        Imported "file://#{source_path}":

        # My First Heading

        My first paragraph.
      EOT
    end

    it 'can parse file URLs with spaces and quotes' do
      file_path = Pathname.pwd.join('spec/assets/example with ".html')
      FileUtils.cp 'spec/assets/example_with_quote.html', file_path
      file_url = "file://#{file_path.to_s.gsub(' ', '%20').gsub('"', '%22')}"
      content, = chat.parse_content("see #{file_url}", [])
      expect(content).to include(<<~EOT)
        Imported "#{file_url}":

        # My First Heading

        My first paragraph.
      EOT
    ensure
      FileUtils.rm_f file_path
    end

    it 'can parse file paths' do
      file_path = Pathname.pwd.join('spec/assets/example.html')
      content, = chat.parse_content("see #{file_path}", [])
      expect(content).to include(<<~EOT)
        Imported "#{file_path}":

        # My First Heading

        My first paragraph.
      EOT
    end

    it 'can parse quoted file paths' do
      file_path = Pathname.pwd.join('spec/assets/example with ".html')
      FileUtils.cp 'spec/assets/example_with_quote.html', file_path
      quoted_file_path = file_path.to_s.gsub('"', '\"')
      content, = chat.parse_content(%{see "#{quoted_file_path}"}, [])
      expect(content).to include(<<~EOT)
        Imported "#{quoted_file_path}":

        # My First Heading

        My first paragraph.
      EOT
    ensure
      FileUtils.rm_f file_path
    end

    it 'can parse file path with escaped spaces' do
      file_path = Pathname.pwd.join('spec/assets/example with .html')
      FileUtils.cp 'spec/assets/example_with_quote.html', file_path
      quoted_file_path = file_path.to_s.gsub(' ', '\\ ')
      content, = chat.parse_content(%{see #{quoted_file_path}}, [])
      expect(content).to include(<<~EOT)
        Imported "#{file_path}":

        # My First Heading

        My first paragraph.
      EOT
    ensure
      FileUtils.rm_f file_path
    end

    it 'can add images' do
      images = []
      expect(chat).to receive(:add_image).
        with(images, kind_of(IO), %r(/spec/assets/kitten\.jpg\z)).
        and_call_original
      chat.parse_content('./spec/assets/kitten.jpg', images)
      expect(images.size).to eq 1
      expect(images.first).to be_a Ollama::Image
    end

    context 'document_policy' do
      it 'can be ignoring' do
        chat.document_policy.selected = 'ignoring'
        c = "see #{Dir.pwd}/spec/assets/example.html"
        content, = chat.parse_content(c, [])
        expect(content).to eq(c)
      end

      it 'can be importing' do
        chat.document_policy.selected = 'importing'
        c = "see #{Dir.pwd}/spec/assets/example.html"
        content, = chat.parse_content(c, [])
        expect(content).to include(<<~EOT)
          Imported "#{Pathname.pwd.join('spec/assets/example.html')}":

          # My First Heading

          My first paragraph.
        EOT
      end

      it 'can be embedding' do
        chat.document_policy.selected = 'embedding'
        c = "see #{Dir.pwd}/spec/assets/example.html"
        expect(chat).to receive(:embed_source).with(
          kind_of(IO),
          Pathname.pwd.join('spec/assets/example.html').to_s
        )
        content, = chat.parse_content(c, [])
        expect(content).to eq c
      end

      it 'can be summarizing' do
        chat.document_policy.selected = 'summarizing'
        c = "see #{Dir.pwd}/spec/assets/example.html"
        content, = chat.parse_content(c, [])
        expect(content).to start_with(<<~EOT)
          see #{Pathname.pwd.join('spec/assets/example.html')}

          Generate an abstract summary of the content in this document using
          100 words:

          # My First Heading

          My first paragraph.
        EOT
      end
    end

    it 'generates a readable directory‑structure string for directories' do
      content, = chat.parse_content("look at #{asset}", [])
      json_data = content.lines[2..-1].join('')
      json = JSON(json_data)
      expect(json.map { _1['name'] }.sort).to eq(
        ["api_show.json", "api_tags.json", "api_version.json",
         "conversation.json", "deep", "duckduckgo.html", "example.atom",
         "example.csv", "example.html", "example.pdf", "example.ps",
         "example.rb", "example.rss", "example.xml", "example_with_quote.html",
         "kitten.jpg", "prompt.txt", "searxng.json"]
      )
    end
  end
end
