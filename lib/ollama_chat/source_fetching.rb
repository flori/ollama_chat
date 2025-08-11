module OllamaChat::SourceFetching
  # The http_options method prepares HTTP options for requests based on
  # configuration settings.
  # It determines whether SSL peer verification should be disabled for a given
  # URL and whether a proxy should be used, then returns a hash of options.
  #
  # @param url [ String ] the URL for which HTTP options are being prepared
  #
  # @return [ Hash ] a hash containing HTTP options such as ssl_verify_peer and
  # proxy settings
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

  # The fetch_source method retrieves content from various source types
  # including commands, URLs, and file paths. It processes the source based on
  # its type and yields a temporary file handle for further processing.
  #
  # @param source [ String ] the source identifier which can be a command, URL, or file path
  #
  # @yield [ tmp ]
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
        headers:      config.request_headers?.to_h,
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
      raise "invalid source #{source.inspect}"
    end
  rescue => e
    STDERR.puts "Cannot fetch source #{source.to_s.inspect}: #{e.class} #{e}\n#{e.backtrace * ?\n}"
  end


  # Adds an image to the images collection from the given source IO and source
  # identifier.
  #
  # This method takes an IO object containing image data and associates it with
  # a source, creating an Ollama::Image instance and adding it to the images
  # array.
  #
  # @param images [Array] The collection of images to which the new image will be added
  # @param source_io [IO] The input stream containing the image data
  # @param source [String, #to_s] The identifier or path for the source of the image
  def add_image(images, source_io, source)
    STDERR.puts "Adding #{source_io&.content_type} image #{source.to_s.inspect}."
    image = Ollama::Image.for_io(source_io, path: source.to_s)
    (images << image).uniq!
  end

  # The import_source method processes and imports content from a given source,
  # displaying information about the document type and returning a formatted
  # string that indicates the import result along with the parsed content.
  #
  # @param source_io [ IO ] the input stream containing the document content
  # @param source [ String ] the source identifier or path
  #
  # @return [ String ] a formatted message indicating the import result and the
  # parsed content
  def import_source(source_io, source)
    source        = source.to_s
    document_type = source_io&.content_type.full? { |ct| italic { ct } + ' ' }
    STDOUT.puts "Importing #{document_type}document #{source.to_s.inspect} now."
    source_content = parse_source(source_io)
    "Imported #{source.inspect}:\n\n#{source_content}\n\n"
  end

  # Imports content from the specified source and processes it.
  #
  # This method fetches content from a given source (command, URL, or file) and
  # passes the resulting IO object to the import_source method for processing.
  #
  # @param source [String] The source identifier which can be a command, URL,
  # or file path
  #
  # @return [String, nil] A formatted message indicating the import result and
  #                       parsed content, #   or nil if the operation fails
  def import(source)
    fetch_source(source) do |source_io|
      content = import_source(source_io, source) or return
      source_io.rewind
      content
    end
  end


  # Summarizes content from the given source IO and source identifier.
  #
  # This method takes an IO object containing document content and generates a
  # summary based on the configured prompt template and word count.
  #
  # @param source_io [IO] The input stream containing the document content to summarize
  # @param source [String, #to_s] The identifier or path for the source of the content
  # @param words [Integer, nil] The target number of words for the summary (defaults to 100)
  # @return [String, nil] The formatted summary message or nil if content is empty or cannot be processed
  def summarize_source(source_io, source, words: nil)
    STDOUT.puts "Summarizing #{italic { source_io&.content_type }} document #{source.to_s.inspect} now."
    words = words.to_i
    words < 1 and words = 100
    source_content = parse_source(source_io)
    source_content.present? or return
    config.prompts.summarize % { source_content:, words: }
  end


  # Summarizes content from the specified source.
  #
  # This method fetches content from a given source (command, URL, or file) and
  # generates a summary using the summarize_source method.
  #
  # @param source [String] The source identifier which can be a command, URL, or file path
  # @param words [Integer, nil] The target number of words for the summary (defaults to 100)
  # @return [String, nil] The formatted summary message or nil if the operation fails
  def summarize(source, words: nil)
    fetch_source(source) do |source_io|
      content = summarize_source(source_io, source, words:) or return
      source_io.rewind
      content
    end
  end


  # Embeds content from the given source IO and source identifier.
  #
  # This method processes document content by splitting it into chunks using
  # various splitting strategies (Character, RecursiveCharacter, Semantic) and
  # adds the chunks to a document store for embedding.
  #
  # @param source_io [IO] The input stream containing the document content to embed
  # @param source [String, #to_s] The identifier or path for the source of the content
  # @param count [Integer, nil] An optional counter for tracking processing order
  #
  # @return [Array, String, nil] The embedded chunks or processed content, or
  # nil if embedding is disabled or fails
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


  # Embeds content from the specified source.
  #
  # This method fetches content from a given source (command, URL, or file) and
  # processes it for embedding using the embed_source method. If embedding is
  # disabled, it falls back to generating a summary instead.
  #
  # @param source [String] The source identifier which can be a command, URL,
  # or file path
  #
  # @return [String, nil] The formatted embedding result or summary message, or
  # nil if the operation fails
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
end
