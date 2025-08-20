require 'tempfile'
require 'tins/unit'
require 'infobar'
require 'mime-types'
require 'stringio'
require 'ollama_chat/utils/cache_fetcher'

class OllamaChat::Utils::Fetcher
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

  class RetryWithoutStreaming < StandardError; end

  # The get method retrieves content from a URL, using caching when available.
  # It processes the URL with optional headers and additional options,
  # then yields a temporary file containing the retrieved content.
  # If caching is enabled and content is found in the cache,
  # it returns the cached result instead of fetching again.
  # The method handles both cached and fresh fetches,
  # ensuring that cache is updated when new content is retrieved.
  #
  # @param url [ String ] the URL to fetch content from
  # @param headers [ Hash ] optional headers to include in the request
  # @param options [ Hash ] additional options for the fetch operation
  #
  # @yield [ tmp ]
  #
  # @return [ Object ] the result of the block execution
  # @return [ nil ] if no block is given or if the fetch fails
  def self.get(url, headers: {}, **options, &block)
    cache = options.delete(:cache) and
      cache = OllamaChat::Utils::CacheFetcher.new(cache)
    cache and infobar.puts "Getting #{url.to_s.inspect} via cache…"
    if result = cache&.get(url, &block)
      infobar.puts "…hit, found#{result.content_type} content in cache."
      return result
    else
      new(**options).send(:get, url, headers:) do |tmp|
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
  # exists
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

  # Makes an HTTP GET request to the specified URL with optional headers and
  # processing block.
  #
  # This method handles both streaming and non-streaming HTTP requests, using
  # Excon for the actual HTTP communication. The response body is written to a
  # temporary file which is then decorated with additional behavior before
  # being passed to the provided block.
  #
  # @param url [String] The URL to make the GET request to
  # @param headers [Hash] Optional headers to include in the request (keys will
  #                       be converted to strings)
  # @yield [Tempfile] The temporary file containing the response body, after
  #                   decoration
  def get(url, headers: {}, &block)
    headers |= self.headers
    headers = headers.transform_keys(&:to_s)
    response = nil
    Tempfile.open do |tmp|
      infobar.label = 'Getting'
      if @streaming
        response = excon(url, headers:, response_block: callback(tmp)).request(method: :get)
        response.status != 200 || !@started and raise RetryWithoutStreaming
        decorate_io(tmp, response)
        infobar.finish
        block.(tmp)
      else
        response = excon(url, headers:, middlewares:).request(method: :get)
        if response.status != 200
          raise "invalid response status code"
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
