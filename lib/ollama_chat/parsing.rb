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
    when %r(\Aapplication/(json|ld\+json|x-ruby|x-perl|x-gawk|x-python|x-javascript|x-c?sh|x-dosexec|x-shellscript|x-tex|x-latex|x-lyx|x-bibtex)), %r(\Atext/), nil
      source_io.read
    else
      STDERR.puts "Cannot parse #{source_io&.content_type} document."
      return
    end
  end

  # The parse_csv method processes CSV content from an input source and
  # converts it into a formatted string representation.
  # It iterates through each row of the CSV, skipping empty rows, and
  # constructs a structured output where each row's fields are formatted with
  # indentation and separated by newlines. The resulting string includes double
  # newlines between rows for readability.
  #
  # @param source_io [ IO ] the input source containing CSV data
  #
  # @return [ String ] a formatted string representation of the CSV content
  def parse_csv(source_io)
    result = +''
    CSV.table(File.new(source_io), col_sep: ?,).each do |row|
      next if row.fields.select(&:present?).none?
      result << row.map { |pair|
        pair.compact.map { _1.to_s.strip } * ': ' if pair.last.present?
      }.select(&:present?).map { _1.prepend('  ') } * ?\n
      result << "\n\n"
    end
    result
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

  # Regular expression to scan content for url/file references
  CONTENT_REGEXP = %r{
    (https?://\S+)                         # Match HTTP/HTTPS URLs
    |                                      # OR
    (?<![a-zA-Z\d])                        # Negative lookbehind: not part of a larger word
    \#                                     # Literal # character (starts a tag)
    ([\w\]\[]+)                            # Tag content: alphanumeric, brackets, underscores
    |                                      # OR
    (file://(?:[^\s#]+))                   # Match file:// URLs
    |                                      # OR
    "((?:\.\.|[~.]?)/(?:\\"|\\|[^"\\]+)+)" # Quoted file path with escaped " quotes
    |                                      # OR
    ((?:\.\.|[~.]?)/(?:\\\ |\\|[^\\\s]+)+) # File path with escaped spaces
  }x
  private_constant :CONTENT_REGEXP

  # Parses content and processes embedded resources based on document policy
  #
  # This method analyzes input content for URLs, tags, and file references,
  # fetches referenced resources, and processes them according to the current
  # document policy. It supports different processing modes for various content
  # types.
  #
  # @param content [String] The input content string to parse
  # @param images [Array] An array to collect image references (will be cleared)
  # @return [Array<String, Documentrix::Utils::Tags>] Returns an array containing
  #   the processed content string and tags object if any tags were found
  def parse_content(content, images)
    images.clear
    tags = Documentrix::Utils::Tags.new valid_tag: /\A#*([\w\]\[]+)/
    contents = [ content ]
    content.scan(CONTENT_REGEXP).each { |url, tag, file_url, quoted_file, file|
      if file && File.directory?(file)
        contents << generate_structure(file)
        next
      end
      check_exist = false
      case
      when tag
        tags.add(tag)
        next
      when url
        links.add(url.to_s)
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
    new_content = contents.select { _1.present? rescue nil }.compact * "\n\n"
    return new_content, (tags unless tags.empty?)
  end
end
