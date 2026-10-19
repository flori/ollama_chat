module OllamaChat::ModelHandling
  # Caches model metadata for one or more Ollama instances.
  #
  # This class provides a simple in-memory cache to store and retrieve
  # model metadata, reducing the need for repeated `ollama show` calls.
  # It supports multiple Ollama instances by using the instance's
  # object ID as part of the cache key.
  class ModelCache
    # Initializes a new model cache.
    def initialize
      @models = Hash.new { |h, k| h[k] = {} }
    end

    # Caches model metadata for a given Ollama instance and model name.
    #
    # @param ollama [Ollama::Client] the Ollama client instance
    # @param name [String, Symbol] the model name
    # @param value [ModelMetadata, nil] the metadata to cache (defaults to nil)
    def cache(ollama, name, value = nil)
      name = name.to_s
      @models[ollama.__id__][name] = value
    end

    # Registers multiple model names as cached for the given Ollama instance.
    #
    # @param ollama [Ollama::Client] the Ollama client instance
    # @param names [Enumerable] a collection of model names to register
    def register_all(ollama, names)
      names.each { |name| cache(ollama, name) }
    end

    # Retrieves cached model metadata for a given Ollama instance and model name.
    #
    # @param ollama [Ollama::Client] the Ollama client instance
    # @param name [String, Symbol] the model name
    # @return [ModelMetadata, nil] the cached metadata, or nil if not cached
    def cached?(ollama, name)
      name = name.to_s
      @models[ollama.__id__][name]
    end

    # Returns a list of cached model names for the given Ollama instance.
    #
    # @param ollama [Ollama::Client] the Ollama client instance
    # @return [Array<String>] the cached model names
    def models(ollama)
      @models[ollama.__id__].keys
    end
  end
end
