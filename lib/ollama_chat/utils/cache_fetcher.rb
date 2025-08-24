require 'digest/md5'

# A cache fetcher implementation that handles caching of HTTP responses with
# content type metadata.
#
# This class provides a mechanism to store and retrieve cached HTTP responses,
# including their content types, using a key-based system. It is designed to
# work with various cache backends and ensures that both the response body and
# metadata are properly cached and retrieved for efficient subsequent requests.
#
# @example Using the CacheFetcher to cache and retrieve HTTP responses
#   cache = Redis.new
#   fetcher = OllamaChat::Utils::CacheFetcher.new(cache)
#   fetcher.put('https://example.com', io)
#   fetcher.get('https://example.com') do |cached_io|
#     # Process cached content
#   end
class OllamaChat::Utils::CacheFetcher
  # The initialize method sets up the cache instance variable for the object.
  #
  # @param cache [ Object ] the cache object to be stored
  #
  # @return [ void ]
  def initialize(cache)
    @cache = cache
  end

  # The get method retrieves cached content by key and yields it as an IO object.
  # It first checks if the body and content type are present in the cache.
  # If both are found, it creates a StringIO object from the body,
  # extends it with HeaderExtension, sets the content type,
  # and then yields the IO object to the provided block.
  #
  # @param url [ String ] the URL used as a key for caching
  #
  # @yield [ io ] yields the cached IO object if found
  def get(url, &block)
    block or raise ArgumentError, 'require block argument'
    body         = @cache[key(:body, url)]
    content_type = @cache[key(:content_type, url)]
    content_type = MIME::Types[content_type].first
    if body && content_type
      io = StringIO.new(body)
      io.rewind
      io.extend(OllamaChat::Utils::Fetcher::HeaderExtension)
      io.content_type = content_type
      block.(io)
    end
  end

  # The put method stores the body and content type of an IO object in the
  # cache using a URL-based key.
  #
  # @param url [ String ] the URL used to generate the cache key
  # @param io [ StringIO, Tempfile ] the IO object containing the body and content type
  #
  # @return [ CacheFetcher ] returns itself to allow for method chaining
  def put(url, io)
    io.rewind
    body = io.read
    body.empty? and return
    content_type = io.content_type
    content_type.nil? and return
    @cache.set(key(:body, url), body, ex: io.ex)
    @cache.set(key(:content_type,  url), content_type.to_s, ex: io.ex)
    self
  end

  private

  # The key method generates a unique identifier by combining a type prefix
  # with a URL digest.
  # It returns a string that consists of the type, a hyphen, and the MD5 hash
  # of the URL.
  #
  # @param type [ String ] the type prefix for categorizing the key
  # @param url [ String ] the URL to be hashed
  #
  # @return [ String ] a hyphen-separated string of the type and URL's MD5 digest
  def key(type, url)
    [ type, Digest::MD5.hexdigest(url) ] * ?-
  end
end
