# A concern that adds one-shot speech capability to any voice handler
# that implements a `#call(response)` streaming method.
#
# The included class (e.g. `OllamaChat::TTS` or `OllamaChat::Say`) is
# expected to have a `#call(response)` method that accepts an object
# responding to `#response` (the text) and `#done` (a completion flag).
# `#speak` wraps that streaming entry point in a one-shot lifecycle:
# optional delayed start on a background thread, a cancel flag, and
# automatic completion via `done: true`.
#
# @example Including Speaker in a handler
#   class MyHandler
#     include OllamaChat::Speaker
#
#     def call(response)
#       speak_text(response.response) if response.response
#       finalize if response.done
#       self
#     end
#   end
module OllamaChat::Speaker
  # Synthesizes and plays a one-shot text via the handler's streaming
  # `#call(response)` method.
  #
  # The text is wrapped in an `OpenStruct` with `done: true` so the
  # handler's `#call` receives the same shape it expects during normal
  # streaming, but with immediate completion. The actual speech synthesis
  # is entirely delegated to the including class's `#call` implementation
  # (e.g. `TTS` buffers → `process_pending_blocks` → `finalize`;
  # `Say` prints to the `say` pipe → closes it).
  #
  # @param text [String] the text to speak
  # @param background [Boolean, Integer] controls execution mode:
  #   - `false` (default): speak inline, blocks until playback finishes
  #   - `true`: spawn a background thread, speak immediately
  #   - a number (e.g. `10`): spawn a background thread that sleeps
  #     for that many seconds before speaking; call {#cancel_speaking}
  #     to abort before the sleep expires
  #
  # @return [self, nil] `self` when a background thread was spawned
  #   (enabling {#cancel_speaking}), `nil` for inline playback
  def speak(text, background: false)
    speaking = -> * do
      if pause = background.ask_and_send(:to_f)
        sleep pause
      end
      @speaking_cancelled and return
      call(OpenStruct.new(response: text, done: true))
    end
    if background
      Thread.new(&speaking)
      self
    else
      speaking.()
      nil
    end
  end

  # Signals a pending background `#speak` to abort before it begins.
  #
  # Always safe to call. Once the speaking thread has already passed
  # the flag check and begun playback, the call has no further effect
  # — the audio is already in the pipe.
  #
  # @return [self] for chaining
  def cancel_speaking
    @speaking_cancelled = true
    self
  end
end
