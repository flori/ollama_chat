module OllamaChat::SourceFetching
  def http_options(url)
    options = {}
    if ssl_no_verify = config.ssl_no_verify?
      hostname = URI.parse(url).hostname
      options |= { ssl_verify_peer: !ssl_no_verify.include?(hostname) }
    end
    if proxy = config.proxy?
      options |= { proxy: }
    end
    options
  end

  def fetch_source(source, &block)
    case source
    when %r(\A!(.*))
      command = $1
      OllamaChat::Utils::Fetcher.execute(command) do |tmp|
        block.(tmp)
      end
    when %r(\Ahttps?://\S+)
      links.add(source.to_s)
      OllamaChat::Utils::Fetcher.get(
        source,
        cache:        @cache,
        debug:        config.debug,
        http_options: http_options(OllamaChat::Utils::Fetcher.normalize_url(source))
      ) do |tmp|
        block.(tmp)
      end
    when %r(\Afile://(/\S*?)#|\A((?:\.\.|[~.]?)/\S*))
      filename = $~.captures.compact.first
      filename = File.expand_path(filename)
      OllamaChat::Utils::Fetcher.read(filename) do |tmp|
        block.(tmp)
      end
    else
      raise "invalid source"
    end
  rescue => e
    STDERR.puts "Cannot fetch source #{source.to_s.inspect}: #{e.class} #{e}\n#{e.backtrace * ?\n}"
  end

  def add_image(images, source_io, source)
    STDERR.puts "Adding #{source_io&.content_type} image #{source.to_s.inspect}."
    image = Ollama::Image.for_io(source_io, path: source.to_s)
    (images << image).uniq!
  end

  def import_source(source_io, source)
    source = source.to_s
    STDOUT.puts "Importing #{italic { source_io&.content_type }} document #{source.to_s.inspect} now."
    source_content = parse_source(source_io)
    "Imported #{source.inspect}:\n\n#{source_content}\n\n"
  end

  def import(source)
    fetch_source(source) do |source_io|
      content = import_source(source_io, source) or return
      source_io.rewind
      content
    end
  end

  def summarize_source(source_io, source, words: nil)
    STDOUT.puts "Summarizing #{italic { source_io&.content_type }} document #{source.to_s.inspect} now."
    words = words.to_i
    words < 1 and words = 100
    source_content = parse_source(source_io)
    source_content.present? or return
    config.prompts.summarize % { source_content:, words: }
  end

  def summarize(source, words: nil)
    fetch_source(source) do |source_io|
      content = summarize_source(source_io, source, words:) or return
      source_io.rewind
      content
    end
  end

  def embed_source(source_io, source, count: nil)
    @embedding.on? or return parse_source(source_io)
    m = "Embedding #{italic { source_io&.content_type }} document #{source.to_s.inspect}."
    if count
      STDOUT.puts '%u. %s' % [ count, m ]
    else
      STDOUT.puts m
    end
    text = parse_source(source_io) or return
    text.downcase!
    splitter_config = config.embedding.splitter
    inputs = nil
    case splitter_config.name
    when 'Character'
      splitter = Documentrix::Documents::Splitters::Character.new(
        chunk_size: splitter_config.chunk_size,
      )
      inputs = splitter.split(text)
    when 'RecursiveCharacter'
      splitter = Documentrix::Documents::Splitters::RecursiveCharacter.new(
        chunk_size: splitter_config.chunk_size,
      )
      inputs = splitter.split(text)
    when 'Semantic'
      splitter = Documentrix::Documents::Splitters::Semantic.new(
        ollama:, model: config.embedding.model.name,
        chunk_size: splitter_config.chunk_size,
      )
      inputs = splitter.split(
        text,
        breakpoint: splitter_config.breakpoint.to_sym,
        percentage: splitter_config.percentage?,
        percentile: splitter_config.percentile?,
      )
    end
    inputs or return
    source = source.to_s
    if source.start_with?(?!)
      source = Kramdown::ANSI::Width.truncate(
        source[1..-1].gsub(/\W+/, ?_),
        length: 10
      )
    end
    @documents.add(inputs, source:, batch_size: config.embedding.batch_size?)
  end

  def embed(source)
    if @embedding.on?
      STDOUT.puts "Now embedding #{source.to_s.inspect}."
      fetch_source(source) do |source_io|
        content = parse_source(source_io)
        content.present? or return
        source_io.rewind
        embed_source(source_io, source)
      end
      config.prompts.embed % { source: }
    else
      STDOUT.puts "Embedding is off, so I will just give a small summary of this source."
      summarize(source)
    end
  end

  def search_web(query, n = nil)
    if l = @messages.at_location.full?
      query += " #{l}"
    end
    n = n.to_i
    n < 1 and n = 1
    query = URI.encode_uri_component(query)
    url = "https://www.duckduckgo.com/html/?q=#{query}"
    OllamaChat::Utils::Fetcher.get(url, debug: config.debug) do |tmp|
      result = []
      doc = Nokogiri::HTML(tmp)
      doc.css('.results_links').each do |link|
        if n > 0
          url = link.css('.result__a').first&.[]('href')
          url.sub!(%r(\A(//duckduckgo\.com)?/l/\?uddg=), '')
          url.sub!(%r(&rut=.*), '')
          url = URI.decode_uri_component(url)
          url = URI.parse(url)
          url.host =~ /duckduckgo\.com/ and next
          links.add(url.to_s)
          result << url
          n -= 1
        else
          break
        end
      end
      result
    end
  end
end
