require 'redis'

# A Redis-based cache implementation for OllamaChat
#
# This class provides a wrapper around Redis that offers a simple key-value
# caching interface with support for expiration times and namespace isolation.
# It's designed to be used as a cache backend for various components in the
# OllamaChat application.
#
# @example Basic usage
#   cache = OllamaChat::RedisCache.new(prefix: 'myapp-', url: 'redis://localhost:6379')
#   cache['key'] = 'value'
#   value = cache['key']
#   cache.delete('key')
#
# @example With expiration
#   cache = OllamaChat::RedisCache.new(prefix: 'expiring-', url: 'redis://localhost:6379', ex: 3600)
#   cache['key'] = 'value' # Automatically expires in 1 hour
#
# @example Iteration
#   cache.each do |key, value|
#     puts "#{key}: #{value}"
#   end
#
# @example Cache management
#   cache.clear # Remove all entries with this prefix
#   size = cache.size # Get number of entries
module OllamaChat
  class RedisCache
    include Enumerable

    # Initializes a new RedisCache instance
    #
    # @param prefix [String] The prefix to use for all keys in this cache
    # @param url [String, nil] The Redis connection URL (defaults to ENV['REDIS_URL'])
    # @param ex [Integer, nil] Default expiration time in seconds
    #
    # @raise [ArgumentError] If no Redis URL is provided
    def initialize(prefix:, url: ENV['REDIS_URL'], ex: nil)
      @prefix = prefix
      @url = url
      @ex = ex
      raise ArgumentError, 'require redis url' unless @url
    end

    # Returns the Redis connection instance
    #
    # This method lazily initializes the Redis connection to avoid
    # establishing connections until they're actually needed.
    #
    # @return [Redis] The Redis client instance
    def redis
      @redis ||= Redis.new(url: @url)
    end

    # Retrieves a value from the cache by key
    #
    # @param key [String] The cache key to retrieve
    # @return [String, nil] The cached value or nil if not found
    def [](key)
      value = redis.get(pre(key))
      value
    end

    # Stores a value in the cache with the given key
    #
    # @param key [String] The cache key
    # @param value [String] The value to cache
    # @return [String] The cached value
    def []=(key, value)
      set(key, value)
    end

    # Stores a value in the cache with optional expiration
    #
    # @param key [String] The cache key
    # @param value [String] The value to cache
    # @param ex [Integer, nil] Expiration time in seconds (overrides default)
    # @return [String] The cached value
    def set(key, value, ex: nil)
      ex ||= @ex
      if !ex.nil? && ex < 1
        redis.del(pre(key))
      else
        redis.set(pre(key), value, ex:)
      end
      value
    end

    # Gets the time-to-live for a key
    #
    # @param key [String] The cache key
    # @return [Integer] The remaining time-to-live in seconds, or -1 if not found
    def ttl(key)
      redis.ttl(pre(key))
    end

    # Checks if a key exists in the cache
    #
    # @param key [String] The cache key to check
    # @return [Boolean] true if the key exists, false otherwise
    def key?(key)
      !!redis.exists?(pre(key))
    end

    # Deletes a key from the cache
    #
    # @param key [String] The cache key to delete
    # @return [Boolean] true if the key was deleted, false if it didn't exist
    def delete(key)
      redis.del(pre(key)) == 1
    end

    # Gets the number of entries in the cache
    #
    # @return [Integer] The number of entries
    def size
      s = 0
      redis.scan_each(match: "#{@prefix}*") { |key| s += 1 }
      s
    end

    # Clears all entries from the cache with this prefix
    #
    # @return [OllamaChat::RedisCache] Returns self for chaining
    def clear
      redis.scan_each(match: "#{@prefix}*") { |key| redis.del(key) }
      self
    end

    # Iterates over all entries in the cache
    #
    # @yield [key, value] Yields each key-value pair
    # @return [OllamaChat::RedisCache] Returns self for chaining
    def each(&block)
      redis.scan_each(match: "#{@prefix}*") { |key| block.(key, self[unpre(key)]) }
      self
    end

    private

    # Prepends the prefix to a key
    #
    # @param key [String] The key to prefix
    # @return [String] The prefixed key
    def pre(key)
      [ @prefix, key ].join
    end

    # Removes the prefix from a key
    #
    # @param key [String] The prefixed key
    # @return [String] The key without prefix
    def unpre(key)
      key.sub(/\A#@prefix/, '')
    end
  end
end
