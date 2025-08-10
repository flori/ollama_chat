module OllamaChat::DocumentCache
  # The document_cache_class method returns the cache class specified in the
  # configuration.
  #
  # @return [ Class ] the cache class defined by the config.cache setting
  def document_cache_class
    Object.const_get(config.cache)
  end

  # The configure_cache method determines the appropriate cache class to use
  # for document storage.
  # It checks if the -M option was specified to use MemoryCache, otherwise it
  # attempts to use the configured cache class.
  # If an error occurs during this process, it falls back to using MemoryCache
  # and reports the error.
  #
  # @return [ Class ] the selected cache class to be used for document caching
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
