module OllamaChat::WebSearching
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

  def search_engine
    config.web_search.use
  end

  def search_web_with_searxng(query, n)
    url = config.web_search.engines.searxng.url % { query: }
    OllamaChat::Utils::Fetcher.get(
      url,
      headers: config.request_headers?.to_h,
      debug:   config.debug
    ) do |tmp|
      data = JSON.parse(tmp.read, object_class: JSON::GenericObject)
      data.results.first(n).map(&:url)
    end
  end

  def search_web_with_duckduckgo(query, n)
    url = config.web_search.engines.duckduckgo.url % { query: }
    OllamaChat::Utils::Fetcher.get(
      url,
      headers: config.request_headers?.to_h,
      debug:   config.debug
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
