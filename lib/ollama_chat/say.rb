# A handler that uses the system's say command to speak response content.
#
# This class extends Ollama::Handlers::Say to provide voice validation
# against the system's available voices. It ensures that only valid voices
# are used, falling back to nil if an invalid voice is specified.
#
# @example Using the Say handler
#   OllamaChat::Say.new(chat: chat, voice: 'Samantha')
class OllamaChat::Say < Ollama::Handlers::Say
  # Returns a list of available system voices.
  #
  # This method queries the system's `say` command to retrieve the list of
  # available voices. If running within RSpec, it returns an empty array to
  # avoid side effects during testing.
  #
  # @return [Array<String>] a sorted list of unique voice identifiers
  def self.voices
    `say -v '?' 2>/dev/null`.lines.map { |l| l[/^(.+?)\s+[a-z]{2}_[a-zA-Z0-9]{2,}/, 1] }.uniq.sort
  end

  # Initializes a new Say handler.
  #
  # @param chat [OllamaChat::Chat] the chat instance
  # @param voice [String, nil] the voice to use (must be in the list of available voices)
  def initialize(chat:, voice: nil)
    voice && self.class.voices.member?(voice) or voice = nil
    @chat  = chat
    super(voice:)
  end
end
