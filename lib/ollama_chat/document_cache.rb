# Module for handling document caching and retrieval using embedding
# similarity.
#
# This module provides methods to configure cache backends and manage document
# storage with semantic search capabilities. It integrates with Documentrix's
# document management system to enable efficient storage, retrieval, and
# similarity-based searching of documents using vector embeddings.
module OllamaChat::DocumentCache
  # Retrieves the cache class specified in the configuration.
  #
  # This method resolves the cache class name from the application's
  # configuration to dynamically load the appropriate cache implementation.
  #
  # @return [Class] The cache class referenced by the configuration's cache
  #   setting.
  # @raise [NameError] If the configured cache class name does not correspond
  #   to an existing constant.
  def document_cache_class
    Object.const_get(config.cache)
  end

  # Configures and returns the appropriate cache class based on command-line
  # options.
  #
  # Determines which cache implementation to use based on command-line flags:
  # - If the `-M` flag is set, uses {Documentrix::Documents::MemoryCache}
  # - Otherwise, resolves and returns the cache class specified in
  #   configuration
  #
  # Falls back to {Documentrix::Documents::MemoryCache} if configuration
  # resolution fails.
  #
  # @return [Class] The selected cache class for document storage and
  #   retrieval.
  # @raise [StandardError] If there is an error resolving the configured cache
  #   class, logs the error to standard error and falls back to MemoryCache.
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
