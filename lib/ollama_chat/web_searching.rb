# A module that provides web search functionality for OllamaChat.
#
# The WebSearching module encapsulates the logic for performing web searches
# using configured search engines. It handles query construction information
# integration, and delegates to engine-specific implementations for retrieving
# search results. The module supports multiple search engines including SearxNG
# and DuckDuckGo, making it flexible for different deployment
# scenarios and privacy preferences.
#
# @example Performing a web search
#   chat.search_web('ruby programming tutorials', 5)
module OllamaChat::WebSearching
  # The search_web method performs a web search using the configured search
  # engine.
  # It limits the number of results.
  # The method delegates to engine-specific search methods based on the
  # configured search engine.
  #
  # @param query [ String ] the search query string
  # @param n [ Integer ] the maximum number of results to return
  #
  # @return [ Array<String>, nil ] an array of URLs from the search results or
  #   nil if the search engine is not implemented
  def search_web(query, n = nil)
    n     = n.to_i.clamp(1..)
    query = URI.encode_uri_component(query)
    search_command = :"search_web_with_#{search_engine}"
    if respond_to?(search_command, true)
      send(search_command, query, n).tap do |results|
        results.each { |url| links.add(url) }
      end
    else
      STDOUT.puts "Search engine #{bold{search_engine}} not implemented!"
      nil
    end
  end

  # Performs a web search and processes the results based on document processing configuration.
  #
  # Searches for the given query using the configured search engine and processes up to
  # the specified number of URLs. The processing approach varies based on the current
  # document policy and embedding status:
  #
  # - **Embedding mode**: When `document_policy.selected == 'embedding'` AND `@embedding.on?` is true,
  #   each result is embedded and the query is interpolated into the `web_embed` prompt.
  # - **Summarizing mode**: When `document_policy.selected == 'summarizing'`,
  #   each result is summarized and both query and results are interpolated into the
  #   `web_summarize` prompt.
  # - **Importing mode**: For all other cases, each result is imported and both query and
  #   results are interpolated into the `web_import` prompt.
  #
  # @param count [String] The maximum number of search results to process (defaults to 1)
  # @param query [String] The search query string
  #
  # @return [String, Symbol] The interpolated prompt content when successful,
  #   or :next if no URLs were found or processing failed
  #
  # @example Basic web search
  #   web('3', 'ruby programming tutorials')
  #
  # @example Web search with embedding policy
  #   # With document_policy.selected == 'embedding' and @embedding.on?
  #   # Processes results through embedding pipeline
  #
  # @example Web search with summarizing policy
  #   # With document_policy.selected == 'summarizing'
  #   # Processes results through summarization pipeline
  def web(count, query)
    urls = search_web(query, count.to_i) or return :next
    if document_policy.selected == 'embedding' && @embedding.on?
      prompt = prompt(:web_embed).to_s
      urls.each do |url|
        fetch_source(url) { |url_io| embed_source(url_io, url) }
      end
      prompt.named_placeholders_interpolate({query:})
    elsif document_policy.selected == 'summarizing'
      prompt = prompt(:web_import).to_s
      results = urls.each_with_object('') do |url, content|
        summarize(url).full? do |c|
          content << c.ask_and_send_or_self(:read)
        end
      end
      prompt.named_placeholders_interpolate({query:, results:})
    else
      prompt = prompt(:web_summarize).to_s
      results = urls.each_with_object('') do |url, content|
        import(url).full? do |c|
          content << c.ask_and_send_or_self(:read)
        end
      end
      prompt.named_placeholders_interpolate({query:, results:})
    end
  end

  # The manage_links method handles operations on a collection of links, such
  # as displaying them or clearing specific entries.
  #
  # It supports two main commands: 'clear' and nil (default).
  # When the command is 'clear', it presents an interactive menu to either
  # clear all links or individual links.
  # When the command is nil, it displays the current list of links with
  # hyperlinks.
  #
  # @param command [ String, nil ] the operation to perform on the links
  def manage_links(command)
    case command
    when 'clear'
      loop do
        links_options = links.dup.add('[EXIT]').add('[ALL]')
        link = OllamaChat::Utils::Chooser.choose(links_options, prompt: 'Clear? %s')
        case link
        when nil, '[EXIT]'
          STDOUT.puts "Exiting chooser."
          break
        when '[ALL]'
          if confirm?(prompt: '🔔 Are you sure? (y/n) ', yes: /\Ay/i)
            links.clear
            STDOUT.puts "Cleared all links in list."
            break
          else
            STDOUT.puts 'Cancelled.'
            sleep 3
          end
        when /./
          links.delete(link)
          STDOUT.puts "Cleared link from links in list."
          sleep 3
        end
      end
    when nil
      if links.empty?
        STDOUT.puts "List is empty."
      else
        w       = Math.log10(links.size + 1).ceil
        format  = "%#{w}s. %s"
        connect = -> link { hyperlink(link) { link } }
        STDOUT.puts links.each_with_index.map { |x, i| format % [ i + 1, connect.(x) ] }
      end
    end
  end

  private

  # The search_engine method returns the currently configured web search engine
  # to be used for online searches.
  #
  # @return [ String ] the name of the web search engine
  def search_engine
    config.web_search.use
  end

  # The search_web_with_searxng method performs a web search using the SearxNG
  # engine and returns the URLs of the first n search results.
  #
  # @param query [ String ] the search query string
  # @param n [ Integer ] the number of search results to return
  #
  # @return [ Array<String> ] an array of URLs from the search results
  def search_web_with_searxng(query, n)
    url = config.web_search.engines.searxng.url % { query: }
    get_url(url, cache:) do |tmp|
      data = JSON.parse(tmp.read, object_class: JSON::GenericObject)
      data.results.first(n).map(&:url)
    end
  end

  # The search_web_with_duckduckgo method performs a web search using the
  # DuckDuckGo search engine and extracts URLs from the search results.
  #
  # @param query [ String ] the search query string to be used
  # @param n [ Integer ] the maximum number of URLs to extract from the search
  #   results
  #
  # @return [ Array<String> ] an array of URL strings extracted from the search
  #   results
  def search_web_with_duckduckgo(query, n)
    url = config.web_search.engines.duckduckgo.url % { query: }
    get_url(url, cache:) do |tmp|
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
          url = url.to_s
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
