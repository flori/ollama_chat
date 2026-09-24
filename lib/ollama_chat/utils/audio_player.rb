# A robust audio player that streams raw PCM data to ffplay.
#
# This class solves the issue of ffplay hanging when data arrives late by
# injecting silence chunks into the pipe. It uses a background thread and
# a Queue to decouple audio fetching from playback, ensuring smooth
# continuous audio even if the TTS backend is slow.
#
# @example Basic usage
#   player = AudioPlayer.new.start
#   player.push(audio_data)
#   player.stop
class OllamaChat::Utils::AudioPlayer
  # Creates a new AudioPlayer instance.
  #
  # @param command [Array<String>] the command to execute for playback
  # @param frequency [Integer] the sample rate of the audio (defaults to 24_000)
  # @param bits [Integer] the bit depth of the audio (defaults to 16)
  # @param pause [Float] the duration of silence to inject when the queue is empty (defaults to 0.01)
  #
  # @return [AudioPlayer] a new instance configured with the given parameters
  def initialize(command: nil, frequency: nil, bits: nil, pause: nil)
    config = OC::OLLAMA::CHAT::AUDIO_PLAYER_CONFIG? or
      raise 'env var %s is required' % (
        OC::OLLAMA::CHAT::AUDIO_PLAYER_CONFIG!.env_var_name.inspect
      )
    command   ||= config.command
    frequency ||= config.frequency
    bits      ||= config.bits
    pause     ||= config.pause
    @audio_queue   = Queue.new
    @playing       = false
    @command       = command
    @frequency     = frequency.to_f
    @bits          = bits
    @pause         = pause.to_f
    @silence_chunk = silent_bytes(@pause)
  end

  # Starts the background playback thread.
  #
  # This method launches a thread that opens a pipe to ffplay and begins
  # consuming audio chunks from the internal queue. If the queue is empty,
  # it writes silence to keep the stream alive.
  #
  # @return [self] returns the player instance for chaining
  def start
    @playing and return self
    @playing = true
    @thread = Thread.new do
      IO.popen("#@command >/dev/null 2>&1", "w") do |io|
        io.binmode
        io.sync = true

        while playing?
          chunk = @audio_queue.shift(true) rescue nil
          if chunk
            io.write(chunk)
          else
            io.write(@silence_chunk)
            sleep @pause
          end
        end
      end
    end
    self
  end

  # Plays audio using a block-based iterator pattern.
  #
  # This method simplifies lifecycle management by automatically starting the
  # player before yielding and stopping it afterwards, ensuring the playback
  # thread is properly cleaned up.
  #
  # @yield [player] Yields the AudioPlayer instance to the block.
  # @raise [ArgumentError] if no block is given.
  #
  # @example
  #   audio_player.play do |ap|
  #     ap << audio_chunk_1
  #     ap << audio_chunk_2
  #   end
  def play(&block)
    block or raise ArgumentError, 'require &block argument'
    start
    block.(self)
    stop
  end

  # Checks if the player is currently active or has pending audio.
  #
  # The player is considered "playing" if the `@playing` flag is true
  # or if there are still audio chunks waiting in the queue.
  #
  # @return [Boolean] true if the player is active or queue is non-empty
  def playing?
    @playing || @audio_queue.present?
  end

  # Stops the playback and waits for the background thread to finish.
  #
  # This sets the playing flag to false and joins the thread, ensuring
  # all resources are cleaned up properly.
  #
  # @return [self] returns the player instance
  def stop
    @playing = false
    @thread&.join
    self
  end

  # Pushes an audio chunk to the playback queue.
  #
  # @param chunk [String] the raw PCM audio bytes to play
  # @return [self] returns the player instance for chaining
  def push(chunk)
    @audio_queue.push(chunk)
    start
  end

  # Alias for push, allowing the << operator for adding audio chunks.
  alias << push

  # Returns a string representation of the player's current state.
  #
  # @return [String] a summary including playing status, pause duration,
  #   and silence chunk size
  def to_s
    "playing=#{playing?} pause=#@pause #{@silence_chunk.bytesize} B"
  end

  # Returns a detailed inspection string for debugging.
  #
  # @return [String] a formatted string with class name and state details
  def inspect
    "#<#{self.class}: #{to_s}>"
  end

  private

  # Generates a silence chunk of PCM null bytes for the given duration.
  #
  # @param duration [Float] the duration of silence in seconds
  # @return [String] a binary string of zero bytes representing silence
  def silent_bytes(duration)
    "\x00" * ((@frequency * (@bits / 8) * duration)).ceil
  end
end
