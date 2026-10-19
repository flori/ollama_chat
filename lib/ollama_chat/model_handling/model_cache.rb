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
      @models     = Hash.new { |h, k| h[k] = {} }
      @sizes      = Hash.new { |h, k| h[k] = {} }
      @registered = Hash.new(false)
    end

    # Caches model metadata (and optionally size) for a given Ollama
    # instance and model name.
    #
    # Existing metadata is never overwritten (`||=`); only missing
    # entries are filled in. Size, when provided, overwrites unconditionally.
    #
    # @param ollama [Ollama::Client] the Ollama client instance
    # @param name [String, Symbol] the model name
    # @param value [ModelMetadata, nil] the metadata to cache (defaults to nil)
    # @param size [Integer, nil] the model size in bytes (optional)
    # @return [ModelMetadata, nil] the cached metadata
    def cache(ollama, name, value = nil, size: nil)
      name = name.to_s
      @models[ollama.__id__][name]         ||= value
      size and @sizes[ollama.__id__][name]   = size
      @models[ollama.__id__][name]
    end

    # Returns the cached `ModelMetadata` for a given model, if it has
    # been fetched. Note: this is a *metadata* predicate, not an
    # existence check. A model can be registered (via `models`) and
    # have a size, yet still return `nil` here until metadata is
    # explicitly cached (e.g. by `model_present?`).
    #
    # @param ollama [Ollama::Client] the Ollama client instance
    # @param name [String, Symbol] the model name
    # @return [ModelMetadata, nil] the metadata if fetched, nil otherwise
    def cached?(ollama, name)
      name = name.to_s
      @models[ollama.__id__][name]
    end

    # Returns the cached size in bytes for a given model.
    #
    # @param ollama [Ollama::Client] the Ollama client instance
    # @param name [String, Symbol] the model name
    # @return [Integer] the size in bytes, 0 if not cached
    def model_size(ollama, name)
      @sizes[ollama.__id__][name].to_i
    end

    # Returns a list of cached model names for the given Ollama instance.
    #
    # @param ollama [Ollama::Client] the Ollama client instance
    # @return [Array<String>] the cached model names
    def models(ollama)
      registered?(ollama) or register_all(ollama)
      @models[ollama.__id__].keys
    end

    # Flushes cached metadata and sizes for one or all Ollama instances.
    #
    # @param ollama [Ollama::Client, Integer, nil] an Ollama client instance,
    #   a raw object ID, or `nil` to flush all instances (default: nil)
    # @return [true]
    def flush(ollama = nil)
      if ollama
        ollama_id = ollama.ask_and_send(:to_int) || ollama.__id__
        @models[ollama_id].clear
        @sizes[ollama_id].clear
        @registered[ollama_id] = false
      else
        @models.each_key { |ollama_id| flush(ollama_id) }
      end
      true
    end

    private

    # Checks whether model registration has been completed for the instance.
    #
    # @param ollama [Ollama::Client] the Ollama client instance
    # @return [Boolean]
    def registered?(ollama)
      @registered[ollama.__id__]
    end

    # Registers multiple model names as cached for the given Ollama instance.
    #
    # @param ollama [Ollama::Client] the Ollama client instance
    #
    # @return [ ModelCache ] this cache instance
    def register_all(ollama)
      ollama.tags.models.each do |model|
        cache(ollama, model.name, size: model.size)
      end
      @registered[ollama.__id__] = true
      self
    end
  end
end
