require 'tempfile'
require 'tins/unit'
require 'infobar'
require 'mime-types'
require 'stringio'
require 'ollama_chat/utils/cache_fetcher'

# A fetcher implementation that handles retrieval and caching of HTTP
# resources.
#
# This class provides functionality to fetch content from URLs, with support
# for caching responses and their metadata. It handles various content types
# and integrates with different cache backends to improve performance by
# avoiding redundant network requests.
#
# @example Fetching content from a URL with caching
#   fetcher = OllamaChat::Utils::Fetcher.new(cache: redis_cache)
#   fetcher.get('https://example.com/data.json') do |tmp|
#     # Process the fetched content
#   end
class OllamaChat::Utils::Fetcher
  # A module that extends IO objects with content type metadata and expiration
  # tracking.
  #
  # This module provides a way to attach MIME content type information and
  # cache expiration details to IO objects, enabling them to carry metadata
  # about their source and caching behavior. It is primarily used by fetcher
  # implementations to decorate response objects with additional context for
  # processing and caching decisions.
  #
  # @example Extending an IO object with header metadata
  #   io = StringIO.new("content")
  #   io.extend(OllamaChat::Utils::Fetcher::HeaderExtension)
  #   io.content_type = MIME::Types['text/plain'].first
  #   io.ex = 3600
  module HeaderExtension
    # The content_type method accesses the content type attribute of the object.
    #
    # @return [ String ] the content type of the object.
    attr_accessor :content_type

    # The ex accessor is used to get or set the expiry value in seconds.
    attr_accessor :ex

    # The failed method creates a StringIO object with a text/plain content type.
    #
    # This method is used to generate a failed response object that can be used
    # when an operation does not succeed. It initializes a new StringIO object
    # and extends it with the current class, setting its content type to
    # text/plain.
    #
    # @return [ StringIO ] a StringIO object with text/plain content type
    def self.failed
      object = StringIO.new.extend(self)
      object.content_type = MIME::Types['text/plain'].first
      object
    end
  end

  # A custom error class raised when retrying HTTP requests without streaming.
  #
  # This exception is specifically used in the Fetcher class to indicate that
  # an HTTP request should be retried using a non-streaming approach when a
  # streaming attempt fails or is not supported.
  #
  # @example Handling the RetryWithoutStreaming error
  #   begin
  #     fetcher.get('https://example.com')
  #   rescue RetryWithoutStreaming
  #     # Handle retry with non-streaming method
  #   end
  class RetryWithoutStreaming < OllamaChat::OllamaChatError; end

  # Fetches the content located at +url+ and optionally caches it.
  #
  # This is a convenience wrapper around an instance of
  # `OllamaChat::Utils::Fetcher`.  It accepts the same options as the
  # instance method, with the following additions:
  #
  # * `:cache` – an object that responds to `get` and `put` (see
  #   `OllamaChat::Utils::CacheFetcher`).  If a cached value exists,
  #   it is returned immediately and the network is not contacted.
  # * `:reraise` – if true, any exception raised during the fetch
  #   will be re‑raised after a failed temporary file has been yielded.
  #   The exception type `OllamaChat::HTTPError` is raised only when
  #   `:reraise` is true; otherwise the error is swallowed and the
  #   caller receives a failed `StringIO` via the block.
  #
  # The method streams the HTTP response into a temporary file (or a
  # `StringIO` in the event of a failure).  The temporary file is
  # extended with `HeaderExtension`, so the block can inspect
  # `tmp.content_type` and `tmp.ex`.  After the block returns the
  # temporary file is closed and discarded.  If a cache is supplied
  # and the response is not a `StringIO`, the temporary file is written
  # back to the cache for future requests.
  #
  # @param url [String] the URL to fetch
  # @param headers [Hash] optional HTTP headers to send with the request
  # @param options [Hash] additional options
  #   * `:cache`          – a cache object (see above)
  #   * `:reraise`        – see description above
  #   * `:middlewares`    – array of Excon middleware classes
  #   * `:http_options`   – hash of options forwarded to the Excon client
  #
  # @yield [tmp] Gives the caller a `Tempfile` (or a `StringIO` in case of
  #   failure) that contains the fetched content.  The yielded object
  #   is already extended with `HeaderExtension`, so the block can read
  #   `tmp.content_type` and `tmp.ex`.
  #
  # @return [Object] the value returned by the block.  If no block is
  #   given, the method returns `nil`.  If a cached value is returned,
  #   the cached object (typically a `StringIO`) is returned directly.
  #
  # @raise [OllamaChat::HTTPError] when the HTTP response status is not
  #   200 **and** the `:reraise` option is true.  The error is raised
  #   after the failed `StringIO` has been yielded to the caller.
  # @raise [OllamaChat::OllamaChatError] (or subclasses) for other
  #   network or I/O errors.  If `:reraise` is true, the original
  #   exception is re‑raised after yielding the failed `StringIO`.
  #
  # @example Fetch a URL with caching
  #   cache = RedisCache.new
  #   fetcher = OllamaChat::Utils::Fetcher
  #   fetcher.get('https://example.com/data.json', cache: cache) do |tmp|
  #     JSON.parse(tmp.read)
  #   end
  #
  # @see OllamaChat::Utils::CacheFetcher
  # @see HeaderExtension
  def self.get(url, headers: {}, **options, &block)
    cache = options.delete(:cache) and
      cache = OllamaChat::Utils::CacheFetcher.new(cache)
    reraise = options.delete(:reraise)
    cache and infobar.puts "Getting #{url.to_s.inspect} via cache…"
    if result = cache&.get(url, &block)
      content_type = result&.content_type || 'unknown'
      infobar.puts "…hit, found #{content_type} content in cache."
      return result
    else
      new(**options).send(:get, url, headers:, reraise:) do |tmp|
        result = block.(tmp)
        if cache && !tmp.is_a?(StringIO)
          tmp.rewind
          cache.put(url, tmp)
        end
        result
      end
    end
  end

  # The normalize_url method processes a URL by converting it to a string,
  # decoding any URI components, removing anchors, and then escaping the URL to
  # ensure it is properly formatted.
  def self.normalize_url(url)
    url = url.to_s
    url = URI.decode_uri_component(url)
    url = url.sub(/#.*/, '')
    URI::Parser.new.escape(url).to_s
  end

  # The read method opens a file and extends it with header extension metadata.
  # It then yields the file to the provided block for processing.
  # If the file does not exist, it outputs an error message to standard error.
  #
  # @param filename [ String ] the path to the file to be read
  #
  # @yield [ file ] yields the opened file with header extension
  #
  # @return [ nil ] returns nil if the file does not exist
  # @return [ Object ] returns the result of the block execution if the file
  #   exists
  def self.read(filename, &block)
    if File.exist?(filename)
      File.open(filename) do |file|
        file.extend(OllamaChat::Utils::Fetcher::HeaderExtension)
        file.content_type = MIME::Types.type_for(filename).first
        block.(file)
      end
    else
      STDERR.puts "File #{filename.to_s.inspect} doesn't exist."
    end
  end

  # The execute method runs a shell command and processes its output.
  #
  # It captures the command's standard output and error streams,
  # writes them to a temporary file, and yields the file to the caller.
  # If an exception occurs during execution, it reports the error
  # and yields a failed temporary file instead.
  #
  # @param command [ String ] the shell command to execute
  #
  # @yield [ tmpfile ]
  def self.execute(command, &block)
    Tempfile.open do |tmp|
      unless command =~ /2>&1/
        command += ' 2>&1'
      end
      IO.popen(command) do |io|
        until io.eof?
          tmp.write io.read(1 << 14)
        end
        tmp.rewind
        tmp.extend(OllamaChat::Utils::Fetcher::HeaderExtension)
        tmp.content_type = MIME::Types['text/plain'].first
        block.(tmp)
      end
    end
  rescue => e
    STDERR.puts "Cannot execute #{command.inspect} (#{e})"
    if @debug && !e.is_a?(RuntimeError)
      STDERR.puts "#{e.backtrace * ?\n}"
    end
    yield HeaderExtension.failed
  end

  # The initialize method sets up the fetcher instance with debugging and HTTP
  # configuration options.
  #
  # @param debug [ TrueClass, FalseClass ] enables or disables debug output
  # @param http_options [ Hash ] additional options to pass to the HTTP client
  def initialize(debug: false, http_options: {})
    @debug        = debug
    @started      = false
    @streaming    = true
    @http_options = http_options
  end

  # Fetches the content located at +url+.
  #
  # The method first checks an optional cache (passed via the `:cache` option).
  # If a cached response is found, it is returned immediately.  Otherwise the
  # URL is fetched over HTTP using Excon.  Two modes are supported:
  #
  # * **Streaming** – the response body is streamed directly into a temporary
  #   file.  Progress is reported via `infobar`.  If the first request
  #   fails with a non‑200 status or the streaming mode is not supported,
  #   the method falls back to a non‑streaming request.
  # * **Non‑streaming** – the entire body is read into memory before
  #   being written to the temporary file.
  #
  # The temporary file is yielded to the caller.  The file is extended
  # with `HeaderExtension`, so the block can inspect `content_type` and
  # `ex` (cache‑expiry in seconds).  After the block returns, the
  # temporary file is closed and discarded.
  #
  # If a cache is supplied and the response is not a `StringIO`, the
  # temporary file is written back to the cache for future requests.
  #
  # @param url [String] the URL to fetch
  # @param headers [Hash] optional HTTP headers to send with the request
  # @param options [Hash] additional options
  #   * `:cache`   – an object that responds to `get` and `put` (see
  #     `OllamaChat::Utils::CacheFetcher`).  When present, the method
  #     will attempt to read from the cache before making a network
  #     request.
  #   * `:reraise` – if true, any exception raised during the fetch
  #     will be re‑raised after a failed temporary file is yielded.
  #   * `:middlewares` – an array of Excon middleware classes to apply.
  #   * `:http_options` – hash of options forwarded to the Excon client.
  #
  # @yield [tmp] Gives the caller a `Tempfile` (or a `StringIO` in the
  #   unlikely event of a failure) that contains the fetched content.
  #   The yielded object is already extended with `HeaderExtension`,
  #   so the block can read `tmp.content_type` and `tmp.ex`.
  #
  # @return [Object] the value returned by the block.  If no block is
  #   given, the method returns `nil`.  If a cached value is returned,
  #   the cached object (typically a `StringIO`) is returned directly.
  #
  # @raise [OllamaChat::HTTPError] when the HTTP response status is not
  #   200 **and** the `:reraise` option is true.  The error is raised
  #   after the failed `StringIO` has been yielded to the caller.
  # @raise [OllamaChat::OllamaChatError] (or subclasses) for other
  #   network or I/O errors.  If `:reraise` is true, the original
  #   exception is re‑raised after yielding the failed `StringIO`.
  #
  # @example Fetch a URL with caching
  #   cache = RedisCache.new
  #   fetcher = OllamaChat::Utils::Fetcher
  #   fetcher.get('https://example.com/data.json', cache: cache) do |tmp|
  #     JSON.parse(tmp.read)
  #   end
  #
  # @see OllamaChat::Utils::CacheFetcher
  # @see HeaderExtension
  def get(url, **opts, &block)
    opts.delete(:response_block) and raise ArgumentError, 'response_block not allowed'
    reraise ||= opts.delete(:reraise)
    middlewares = (self.middlewares | Array((opts.delete(:middlewares)))).uniq
    headers = opts.delete(:headers) || {}
    headers |= self.headers
    headers = headers.transform_keys(&:to_s)
    response = nil
    Tempfile.open do |tmp|
      infobar.label = 'Getting'
      if @streaming
        response = excon(url, headers:, response_block: callback(tmp), **opts).request(method: :get)
        response.status != 200 || !@started and raise RetryWithoutStreaming
        decorate_io(tmp, response)
        infobar.finish
        block.(tmp)
      else
        response = excon(url, headers:, middlewares:, **opts).request(method: :get)
        if status = response.status and status != 200
          message = "request failed: %u %s" % [ status, response.reason_phrase ]
          error = OllamaChat::HTTPError.new(message)
          error.status = status
          raise error
        end
        body = response.body
        tmp.print body
        infobar.update(message: message(body.size, body.size), force: true)
        decorate_io(tmp, response)
        infobar.finish
        block.(tmp)
      end
    end
  rescue RetryWithoutStreaming
    @streaming = false
    retry
  rescue => e
    STDERR.puts "Cannot get #{url.to_s.inspect} (#{e}): #{response&.status_line || 'n/a'}"
    if @debug && !e.is_a?(RuntimeError)
      STDERR.puts "#{e.backtrace * ?\n}"
    end
    yield HeaderExtension.failed
    reraise and raise e
  end

  private

  # The excon method creates a new Excon client instance configured with the
  # specified URL and options.
  #
  # @param url [ String ] the URL to be used for the Excon client
  # @param options [ Hash ] additional options to be merged with http_options
  #
  # @return [ Excon ] a new Excon client instance
  #
  # @see #normalize_url
  # @see #http_options
  def excon(url, **options)
    url = self.class.normalize_url(url)
    Excon.new(url, options.merge(@http_options))
  end

  # The headers method returns a hash containing the default HTTP headers
  # that should be used for requests, including a User-Agent header
  # configured with the application's user agent string.
  #
  # @return [ Hash ] a hash mapping header names to their values
  # @note The returned hash includes the 'User-Agent' header
  #       set to OllamaChat::Chat.user_agent.
  def headers
    {
      'User-Agent' => OllamaChat::Chat.user_agent,
    }
  end

  # The middlewares method returns the combined array of default Excon
  # middlewares and the RedirectFollower middleware, ensuring there are no
  # duplicates.
  #
  # @return [ Array ] an array of middleware classes including RedirectFollower
  #                   deduplicated from the default Excon middlewares.
  def middlewares
    (Excon.defaults[:middlewares] + [ Excon::Middleware::RedirectFollower ]).uniq
  end

  private

  # Decorates a temporary IO object with header information from an HTTP
  # response.
  #
  # This method extends the given temporary IO object with HeaderExtension
  # module and populates it with content type and cache expiration information
  # extracted from the provided response headers.
  #
  # @param tmp [IO] The temporary IO object to decorate (typically a file handle)
  # @param response [Object] HTTP response object containing headers
  # @option response [Hash] :headers HTTP headers hash
  def decorate_io(tmp, response)
    tmp.rewind
    tmp.extend(HeaderExtension)
    if content_type = MIME::Types[response.headers['content-type']].first
      tmp.content_type = content_type
    end
    if cache_control = response.headers['cache-control'] and
        cache_control !~ /no-store|no-cache/ and
        ex = cache_control[/s-maxage\s*=\s*(\d+)/, 1] || cache_control[/max-age\s*=\s*(\d+)/, 1]
    then
      tmp.ex = ex.to_i
    end
  end

  # The callback method creates a proc that handles chunked data processing by
  # updating progress information and writing chunks to a temporary file.
  #
  # @param tmp [ Tempfile ] the temporary file to which data chunks are written
  #
  # @return [ Proc ] a proc that accepts chunk, remaining_bytes, and total_bytes
  #                  parameters for processing streamed data
  def callback(tmp)
    -> chunk, remaining_bytes, total_bytes do
      total   = total_bytes or next
      current = total_bytes - remaining_bytes
      if @started
        infobar.counter.progress(by: total - current)
      else
        @started = true
        infobar.counter.reset(total:, current:)
      end
      infobar.update(message: message(current, total), force: true)
      tmp.print(chunk)
    end
  end

  # The message method formats progress information by combining current and
  # total values with unit formatting, along with timing details.
  #
  # @param current [ Integer ] the current progress value
  # @param total [ Integer ] the total progress value
  #
  # @return [ String ] a formatted progress string including units and timing information
  def message(current, total)
    progress = '%s/%s' % [ current, total ].map {
      Tins::Unit.format(_1, format: '%.2f %U')
    }
    '%l ' + progress + ' in %te, ETA %e @%E'
  end
end
