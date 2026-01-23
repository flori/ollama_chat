# A module that provides web search functionality for OllamaChat.
#
# The WebSearching module encapsulates the logic for performing web searches
# using configured search engines. It handles query construction, location
# information integration, and delegates to engine-specific implementations for
# retrieving search results. The module supports multiple search engines
# including SearxNG and DuckDuckGo, making it flexible for different deployment
# scenarios and privacy preferences.
#
# @example Performing a web search
#   chat.search_web('ruby programming tutorials', 5)
module OllamaChat::WebSearching
  # The search_web method performs a web search using the configured search
  # engine.
  # It appends location information to the query if available and limits the
  # number of results.
  # The method delegates to engine-specific search methods based on the
  # configured search engine.
  #
  # @param query [ String ] the search query string
  # @param n [ Integer ] the maximum number of results to return
  #
  # @return [ Array<String>, nil ] an array of URLs from the search results or
  #   nil if the search engine is not implemented
  def search_web(query, n = nil)
    l     = @messages.at_location.full? and query += " #{l}"
    n     = n.to_i.clamp(1..)
    query = URI.encode_uri_component(query)
    search_command = :"search_web_with_#{search_engine}"
    if respond_to?(search_command, true)
      send(search_command, query, n)
    else
      STDOUT.puts "Search engine #{bold{search_engine}} not implemented!"
      nil
    end
  end

  private

  # The search_engine method returns the currently configured web search engine
  # to be used for online searches.
  #
  # @return [ String ] the name of the web search engine
  # @see OllamaChat::Config::WebSearch#use
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
    OllamaChat::Utils::Fetcher.get(
      url,
      headers: config.request_headers?.to_h,
      debug:
    ) do |tmp|
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
    OllamaChat::Utils::Fetcher.get(
      url,
      headers: config.request_headers?.to_h,
      debug:
    ) do |tmp|
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
          links.add(url)
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
