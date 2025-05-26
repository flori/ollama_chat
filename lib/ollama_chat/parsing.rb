module OllamaChat::Parsing
  def parse_source(source_io)
    case source_io&.content_type
    when 'text/html'
      reverse_markdown(source_io.read)
    when 'text/xml'
      if source_io.read(8192) =~ %r(^\s*<rss\s)
        source_io.rewind
        return parse_rss(source_io)
      end
      source_io.rewind
      source_io.read
    when 'text/csv'
      parse_csv(source_io)
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
      STDERR.puts "Cannot embed #{source_io&.content_type} document."
      return
    end
  end

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

  def pdf_read(io)
    reader = PDF::Reader.new(io)
    reader.pages.inject(+'') { |result, page| result << page.text }
  end

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

  def reverse_markdown(html)
    ReverseMarkdown.convert(
      html,
      unknown_tags: :bypass,
      github_flavored: true,
      tag_border: ''
    )
  end

  def parse_content(content, images)
    images.clear
    tags = Documentrix::Utils::Tags.new valid_tag: /\A#*([\w\]\[]+)/

    contents = [ content ]
    content.scan(%r((https?://\S+)|(?<![a-zA-Z\d])#+([\w\]\[]+)|(?:file://)?(\S*\/\S+))).each do |url, tag, file|
      case
      when tag
        tags.add(tag)
        next
      when file
        file = file.sub(/#.*/, '')
        file =~ %r(\A[~./]) or file.prepend('./')
        File.exist?(file) or next
        source = file
      when url
        links.add(url.to_s)
        source = url
      end
      fetch_source(source) do |source_io|
        case source_io&.content_type&.media_type
        when 'image'
          add_image(images, source_io, source)
        when 'text', 'application', nil
          case @document_policy
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
    end
    new_content = contents.select { _1.present? rescue nil }.compact * "\n\n"
    return new_content, (tags unless tags.empty?)
  end
end
