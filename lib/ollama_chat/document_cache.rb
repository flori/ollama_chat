module OllamaChat::DocumentCache
  def document_cache_class
    Object.const_get(config.cache)
  end

  def configure_cache
    if @opts[?M]
      Documentrix::Documents::MemoryCache
    else
      document_cache_class
    end
  rescue => e
    STDERR.puts "Caught #{e.class}: #{e} => Falling back to MemoryCache."
    Documentrix::Documents::MemoryCache
  end
end
