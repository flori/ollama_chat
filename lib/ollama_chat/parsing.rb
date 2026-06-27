# A module that provides content parsing functionality for OllamaChat.
#
# The Parsing module encapsulates methods for processing various types of input
# sources including HTML, XML, CSV, RSS, Atom, PDF, and Postscript documents.
# It handles content extraction and conversion into standardized text formats
# suitable for chat interactions. The module supports different document
# policies for handling imported or embedded content and provides utilities for
# parsing structured data from multiple source types.
#
# @example Processing different document types
#   chat.parse_source(html_io)    # Converts HTML to markdown
#   chat.parse_source(pdf_io)     # Extracts text from PDF files
#   chat.parse_source(csv_io)     # Formats CSV data into readable strings
module OllamaChat::Parsing
  include OllamaChat::Utils::AnalyzeDirectory

  # An array of valid document policy states that define how document
  # references in user text are handled.
  #
  # These states control the behavior of the document policy selector:
  # * `ignoring`: Document references are ignored.
  # * `embedding`: Document references are embedded into the conversation
  #   context for RAG.
  # * `importing`: Document references are imported into the conversation.
  # * `summarizing`: Document references are summarized for reference.
  DOCUMENT_POLICY_STATES = %w[ ignoring embedding importing summarizing ]

  # The parse_source method processes different types of input sources and
  # converts them into a standardized text representation.
  #
  # @param source_io [IO] the input source to be parsed
  #
  # @return [ String, nil ] the parsed content as a string or nil if the
  #   content type is not supported
  def parse_source(source_io)
    case source_io&.content_type
    when 'text/html'
      reverse_markdown(source_io.read)
    when 'text/xml', 'application/xml'
      if source_io.read(8192) =~ %r(^\s*<rss\s)
        source_io.rewind
        return parse_rss(source_io)
      end
      source_io.rewind
      source_io.read
    when 'application/rss+xml'
      parse_rss(source_io)
    when 'application/atom+xml'
      parse_atom(source_io)
    when 'application/postscript'
      ps_read(source_io)
    when 'application/pdf'
      pdf_read(source_io)
    when 'image/png'
      results = parse_png(source_io) and return results.join("\n\n---\n\n")
      STDERR.puts "Could not parse metadata from #{source_io&.content_type} document."
      nil
    when %r(\Aapplication/(json|ld\+json|x-ruby|x-perl|x-gawk|x-python|x-javascript|x-c?sh|x-dosexec|x-shellscript|x-tex|x-latex|x-lyx|x-bibtex)), %r(\Atext/), nil
      source_io.read
    else
      STDERR.puts "Cannot parse #{source_io&.content_type} document."
      return
    end
  end

  # Extracts embedded metadata from a PNG image, including character profiles,
  # prompts, and workflows. Character profiles are automatically personalized
  # to replace placeholders with the current user's name.
  #
  # @param source_io [IO] The input stream containing the PNG binary data.
  #
  # @return [Array<String>, nil] An array of formatted metadata sections (as
  #   strings) if any were found, or nil if no supported metadata was extracted.
  def parse_png(source_io)
    metadata = OllamaChat::Utils::PNGMetadataExtractor.extract_all(source_io) or return
    results = []

    if data = metadata.delete('chara') and
        char = OllamaChat::Utils::PNGMetadataExtractor.decode_character(data)
      then
      results << "Character Profile:\n\n#{personalize_character_profile(char)}"
    end

    if data = metadata.delete('parameters') and
      params = OllamaChat::Utils::PNGMetadataExtractor.parse_a1111_parameters(data)
    then
      results << "Generation Settings:\n\n#{params.to_json}"
    end

    if data = convert_to_utf8(metadata.delete('prompt'))
      results << "Prompt:\n\n#{data}"
    end

    if data = convert_to_utf8(metadata.delete('workflow'))
      results << "Workflow:\n\n#{data}"
    end

    if data = metadata.full? { _1.transform_values { |v| convert_to_utf8(v) } }
      results << "Metadata:\n\n#{data}"
    end

    results.full?
  end

  # The parse_rss method processes an RSS feed source and converts it into a
  # formatted text representation.
  # It extracts the channel title and iterates through each item in the feed to
  # build a structured output.
  # The method uses the RSS parser to handle the source input and formats the
  # title, link, publication date, and description of each item into a readable
  # text format with markdown-style headers and links.
  #
  # @param source_io [IO] the input stream containing the RSS feed data
  #
  # @return [String] a formatted string representation of the RSS feed with
  #   channel title and item details
  def parse_rss(source_io)
    feed = RSS::Parser.parse(source_io, false, false)
    title = <<~EOT
      # #{feed&.channel&.title}

    EOT
    feed.items.inject(title) do |text, item|
      text << <<~EOT
        ## [#{item&.title}](#{item&.link})

        updated on #{item&.pubDate}

        #{reverse_markdown(item&.description)}

      EOT
    end
  end

  # The parse_atom method processes an Atom feed from the provided IO source
  # and converts it into a formatted text representation.
  # It extracts the feed title and iterates through each item to build a
  # structured output containing titles, links, and update dates.
  #
  # The content of each item is converted using reverse_markdown for better
  # readability.
  #
  # @param source_io [IO] the input stream containing the Atom feed data
  #
  # @return [String] a formatted string representation of the Atom feed with
  #   title, items, links, update dates, and content
  def parse_atom(source_io)
    feed = RSS::Parser.parse(source_io, false, false)
    title = <<~EOT
      # #{feed.title.content}

    EOT
    feed.items.inject(title) do |text, item|
      text << <<~EOT
        ## [#{item&.title&.content}](#{item&.link&.href})

        updated on #{item&.updated&.content}

        #{reverse_markdown(item&.content&.content)}

      EOT
    end
  end

  # The pdf_read method extracts text content from a PDF file by reading all
  # pages.
  #
  # @param io [IO] the input stream containing the PDF data
  #
  # @return [String] the concatenated text content from all pages in the PDF
  def pdf_read(io)
    reader = PDF::Reader.new(io)
    reader.pages.inject(+'') { |result, page| result << page.text }
  end


  # Reads and processes PDF content using Ghostscript for conversion
  #
  # This method takes an IO object containing PDF data, processes it through
  # Ghostscript's pdfwrite device, and returns the processed PDF content.
  # If Ghostscript is not available in the system path, it outputs an error message.
  #
  # @param io [IO] An IO object containing PDF data to be processed
  # @return [String, nil] The processed PDF content as a string, or nil if
  #   processing fails
  def ps_read(io)
    gs = `which gs`.chomp
    if gs.present?
      Tempfile.create do |tmp|
        IO.popen("#{gs} -q -sDEVICE=pdfwrite -sOutputFile=#{tmp.path} -", 'wb') do |gs_io|
          until io.eof?
            buffer = io.read(1 << 17)
            IO.select(nil, [ gs_io ], nil)
            gs_io.write buffer
          end
          gs_io.close
          File.open(tmp.path, 'rb') do |pdf|
            pdf_read(pdf)
          end
        end
      end
    else
      STDERR.puts "Cannot convert #{io&.content_type} whith ghostscript, gs not in path."
    end
  end

  # The reverse_markdown method converts HTML content into Markdown format.
  #
  # This method processes HTML input and transforms it into equivalent
  # Markdown, using specific conversion options to ensure compatibility and
  # formatting.
  #
  # @param html [ String ] the HTML string to be converted
  #
  # @return [ String ] the resulting Markdown formatted string
  def reverse_markdown(html)
    ReverseMarkdown.convert(
      html,
      unknown_tags: :bypass,
      github_flavored: true,
      tag_border: ''
    )
  end

  # Personalizes a character profile by replacing the {{user}} placeholder.
  #
  # @param char [String] The raw character JSON string.
  # @return [String] The personalized character profile.
  def personalize_character_profile(char)
    name = user_name || 'the user'
    char.gsub('{{user}}', name)
  end

  # Regular expression to scan content for url/file references
  CONTENT_REGEXP = %r{
    (https?://\S+)                         # Match HTTP/HTTPS URLs
    |                                      # OR
    (file://(?:[^\s#]+))                   # Match file:// URLs
    |                                      # OR
    "((?:\.\.|[~.]?)/(?:\\"|\\|[^"\\]+)+)" # Quoted file path with escaped " quotes
    |                                      # OR
    ((?:\.\.|[~.]?)/(?:\\\ |\\|[^\\\s]+)+) # File path with escaped spaces
  }x
  private_constant :CONTENT_REGEXP

  # Parses a string for URLs, file refs, and image links, then returns
  # the transformed content.  Detects `http(s)` URLs, `file://` paths,
  # quoted file paths, and collects any image URLs into the supplied
  # `images` array.
  #
  # @param content [String] the raw text to parse
  # @param images  [Array] mutable array that will be cleared
  #                  then filled with discovered image URLs
  #
  # @return [String] the content after all supported transformations
  #   (URLs resolved, file refs expanded, image URLs collected)
  def parse_content(content, images)
    images.clear
    contents = [ content ]
    content.scan(CONTENT_REGEXP).each { |url, file_url, quoted_file, file|
      if file && Pathname.new(file).expand_path.directory?
        contents << generate_structure(file).to_json
        next
      end
      check_exist = false
      case
      when url
        source = url
      when file_url
        check_exist = true
        source      = file_url
      when quoted_file
        file = quoted_file.gsub('\"', ?")
        file =~ %r(\A[~./]) or file.prepend('./')
        check_exist = true
        source      = file
      when file
        file = file.gsub('\ ', ' ')
        file =~ %r(\A[~./]) or file.prepend('./')
        check_exist = true
        source      = file
      end
      fetch_source(source, check_exist:) do |source_io|
        case source_io&.content_type&.media_type
        when 'image'
          add_image(images, source_io, source)
          if source_io&.content_type&.sub_type == 'png'
            source_io.rewind
            if results = parse_png(source_io)
              contents.concat results
            end
          end
        when 'text', 'application', nil
          case document_policy.selected
          when 'ignoring'
            nil
          when 'importing'
            contents << import_source(source_io, source)
          when 'embedding'
            embed_source(source_io, source)
          when 'summarizing'
            contents << summarize_source(source_io, source)
          end
        else
          STDERR.puts(
            "Cannot fetch #{source.to_s.inspect} with content type "\
            "#{source_io&.content_type.inspect}"
          )
        end
      end
    }
    contents.select { _1.present? rescue nil }.compact * "\n\n"
  end
end
