require 'ollama_chat/speaker'

# Text-to-Speech handler for streaming audio playback.
#
# This class handles converting streamed text responses into spoken audio
# using a remote TTS server. It manages parallel TTS requests for text
# blocks while maintaining strict ordering of audio chunks through an
# `OrderedQueue`. A coordinator thread ensures chunks are played in the
# correct sequence, even when multiple TTS requests complete out of order.
#
# @example
#   tts = OllamaChat::TTS.new(chat: chat, voice: 'alloy')
#   tts.call(response)
class OllamaChat::TTS
  include OllamaChat::Utils::UTF8Converter
  include OllamaChat::Utils::ValueFormatter
  include OllamaChat::KramdownANSI
  include OllamaChat::Speaker
  include Ollama::Handlers::Concern

  # Returns a sorted list of available TTS voice IDs.
  #
  # When +model+ is +nil+ the generic `/v1/voices` endpoint is queried
  # and a hash array (`[{"id": "…"}, …]`) is expected. When a model name
  # is given, `/v1/audio/voices?model=<id>` is queried and a string
  # array (`["…", …]`) is expected (audio.cpp convention). If the
  # server is unreachable or returns an error, an empty array is
  # returned.
  #
  # @param model [String, nil] the TTS model ID for per-model queries
  # @param chat [OllamaChat::Chat] the chat instance (for HTTP middleware)
  # @return [Array<String>] a sorted list of unique voice identifiers
  def self.voices(model: nil, chat:)
    url = model ? OC::OLLAMA::CHAT::TTS_URL + "/v1/audio/voices?model=#{model}"
                : OC::OLLAMA::CHAT::TTS_URL + '/v1/voices'
    result = nil
    chat.request_url_response(:get, url) do |response|
      data   = JSON.parse(response.body)
      result = data['voices']
      result = result.map { |v| v['id'] } unless model
    end
    result&.sort || []
  rescue Excon::Error, JSON::ParserError
    []
  end

  # Initializes a new TTS handler.
  #
  # Sets up the audio player, ordered queue for managing audio chunks,
  # and starts a coordinator thread that processes chunks in order.
  #
  # @param chat [OllamaChat::Chat] the chat instance for logging
  # @param voice [String, nil] the voice ID to use for TTS
  #   (must be in the list returned by `self.voices`; falls back to nil
  #   if invalid or not provided)
  #
  # @return [OllamaChat::TTS] a new instance
  def initialize(chat:, voice: nil)
    if voice
      if model = @voice_model = chat.config.voice.model?
        self.class.voices(model:, chat:).member?(voice) or voice = nil
      else
        self.class.voices(chat:).member?(voice) or voice = nil
        @voice_model = 'tts-1'
      end
    end
    @chat              = chat
    @voice             = voice
    @buffer            = +''
    @audio_player      = OllamaChat::Utils::AudioPlayer.new
    @ordered_queue     = OllamaChat::Utils::OrderedQueue.new
    @id_mutex          = Mutex.new
    @next_id           = 0
    @current_thread_id = 1
    @enqueued_count    = 0
    @finished_count    = 0
    @worker_threads    = []
    @coordinator       = Thread.new { run_coordinator }

    super(output: Tins::NULL)
  end

  # The voice attribute reader returns the voice associated with the
  # object.
  #
  # @return [String, nil] the voice ID or nil if not set
  attr_reader :voice

  # The model attribute reader returns the TTS model ID from config.
  #
  # @return [String, nil] the model ID or nil if not configured
  attr_reader :voice_model

  # Processes a streaming response chunk for TTS conversion.
  #
  # Buffers incoming text content and extracts complete blocks (separated
  # by blank lines) for immediate TTS processing. When the response is done,
  # finalizes playback by waiting for all pending TTS requests to complete.
  #
  # @param response [Ollama::Response] the streaming response object
  #   containing text content and a `done` flag
  #
  # @return [self] returns self for chaining
  def call(response)
    if content = response.response || response.message&.content

      @buffer << content

      process_pending_blocks # Process and "read" completed blocks immediately! 🏎️💨
    end

    if response.done
      finalize
    end

    self
  end

  private

  # Processes pending blocks from the buffer.
  #
  # Extracts complete text blocks (terminated by blank lines `\n\n`) from
  # the buffer and enqueues them for TTS conversion. This allows for near-
  # real-time speech synthesis as text arrives incrementally.
  #
  # @note Blocks are identified by double-newline separators, ignoring
  #   leading numbered lists like "1."
  def process_pending_blocks
    loop do
      match = @buffer.match(/\A(.{160,})\n\n/m) || @buffer.match(/\A(.*?)\n\n/m) or break
      size = match[0].size

      chunk = @buffer.slice!(0, size).full?(:strip) or next
      enqueue_tts(chunk)
    end
  end

  # Enqueues a block of text for TTS conversion.
  #
  # Spawns a background thread that fetches audio chunks from the TTS server
  # and pushes them into the ordered queue along with a `:finished` sentinel.
  # Each enqueue operation increments the pending thread counter.
  #
  # @param block [String] the text to convert to speech
  #
  # @return [Thread] the spawned TTS fetch thread
  def enqueue_tts(block)
    block = kramdown_markdown_remove(block, markdown: @chat.markdown.on?)
    thread_id = @id_mutex.synchronize { @next_id += 1 }
    @chat.log(:info, "TTS: Enqueueing block for synthesis", data: { thread_id:, block: })
    @id_mutex.synchronize { @enqueued_count += 1 }

    @worker_threads << Thread.new do
      chunk_id = 0
      data = {
        model:           @voice_model,
        input:           block,
        response_format: 'pcm', # This is currently ignored by audio.cpp 😿
      }
      if stream = @chat.config.voice.stream?&.enabled
        data |= {
          stream:        true,
          stream_format: @chat.config.voice.stream.format,
        }
      else
        data[:stream] = false
      end
      @voice and data[:voice] = @voice

      @ordered_queue.push([thread_id, chunk_id += 1], :started)

      fetch_tts(data) do |chunk|
        @ordered_queue.push([thread_id, chunk_id += 1], chunk)
      end

      @ordered_queue.push([thread_id, chunk_id += 1], :finished)
    end
  end

  # Finalizes TTS playback.
  #
  # Flushes any remaining buffered text, waits for all enqueued TTS threads
  # to complete, stops the audio player, and waits for playback to finish.
  # This ensures all audio is played before the handler shuts down.
  def finalize
    @audio_player.start

    unless @buffer.blank?
      enqueue_tts(@buffer.dup)
      @buffer.clear
    end

    # Wait for all enqueued TTS threads to finish
    sleep 0.1 while @id_mutex.synchronize { @finished_count < @enqueued_count }

    @audio_player.stop
    sleep 0.1 while @audio_player.playing?
  end

  # Joins all worker threads spawned by `enqueue_tts`.
  #
  # Useful for tests that need to ensure all background fetch threads
  # have completed before teardown.
  def join_workers
    @worker_threads.each(&:join)
  end

  # The coordinator loop that processes audio chunks in order.
  #
  # Continuously monitors the ordered queue, popping chunks only when they
  # belong to the current thread (maintaining strict ordering within each
  # TTS request). When a `:finished` sentinel is encountered, switches to
  # the next thread's chunks if available.
  #
  # @note This runs in a background thread started during initialization
  def run_coordinator
    loop do
      item = @ordered_queue.peek

      if item.nil?
        sleep 0.01
        next
      end

      (thread_id, _chunk_id), _payload = item

      if @chat.debug
        @chat.log(
          :debug,
          'TTS: Coordinator peeking queue',
          data: {
            id: [ thread_id, _chunk_id ],
            payload: _payload.is_a?(Symbol) ? _payload : :audio_data,
          }
        )
      end

      @current_thread_id ||= thread_id

      if thread_id == @current_thread_id
        _id, payload = @ordered_queue.pop

        case payload
        when :started
          @chat.log(:info, 'TTS: Block synthesis scheduled', data: {
            id: _id,
            finished: @finished_count,
            pending: (@enqueued_count - @finished_count),
          })
        when :finished
          @id_mutex.synchronize do
            @finished_count += 1
            @chat.log(:info, 'TTS: Block synthesis completed', data: {
              id: _id,
              finished: @finished_count,
              pending: (@enqueued_count - @finished_count),
            })
          end
          next_item = @ordered_queue.peek
          @current_thread_id = next_item ? next_item[0][0] : nil
        else
          if @chat.debug
            @chat.log(
              :debug, 'TTS: Feeding audio chunk to player',
              data: { id: _id, size: format_bytes(payload.bytesize) }
            )
          end
          @audio_player << payload
        end
      else
        sleep 0.01
      end
    end
  end

  # Fetches TTS audio chunks from the remote server.
  #
  # Makes a POST request to the TTS API with the given data, streaming
  # audio chunks back via the provided block. Handles connection timeouts
  # and error responses gracefully.
  #
  # @param data [Hash] the TTS request payload including:
  #   - `:model` [String] the TTS model to use (default: "tts-1")
  #   - `:input` [String] the text to convert
  #   - `:response_format` [String] the audio format (default: "pcm")
  #   - `:stream` [Boolean] whether to stream (default: true)
  #   - `:voice` [String, nil] optional voice ID
  #
  # @yield [chunk] yields each audio chunk (raw PCM bytes)
  # @yieldparam chunk [String] the raw audio data
  #
  # @raise [Excon::Error] on HTTP failure (logged and rescued)
  def fetch_tts(data, &block)
    @chat.log(:info, 'TTS: Requesting audio synthesis', data:)
    body = JSON.dump(data)
    url = OC::OLLAMA::CHAT::TTS_URL + '/v1/audio/speech'
    first_chunk = true
    response_block = -> chunk, _remaining, _total do
      if first_chunk
        first_chunk = false
        # audio.cpp wraps non-streaming responses in a 44-byte RIFF/WAV
        # header regardless of the requested response_format; strip it
        # so the player receives raw PCM.
        chunk = chunk[44..] if chunk.start_with?('RIFF')
      end
      block.call(chunk) unless chunk.empty?
    end
    response = @chat.request_url_response(
      :post, url,
      body:            ,
      headers:         { 'Content-Type' => 'application/json' },
      expects:         200,
      response_block:  ,
      logger:          @chat.debug ? OllamaChat::Utils::ExconLogger.new(@chat) : nil,
    )
  rescue => e
    data = {}
    if response
      result = JSON.parse(response.body) rescue nil
      data[:response] = {
        status: response.status,
        result: ,
      }
    end
    @chat.log(:error, e, data:)
  end
end
