# A lightweight Logger adapter that routes Excon log messages through
# the OllamaChat logging system.
#
# This allows Excon's debug output to be captured and formatted consistently
# with the rest of the application, avoiding direct writes to $stderr.
#
# @example
#   logger = OllamaChat::Utils::ExconLogger.new(chat)
#   excon = Excon.new(url, logger:)
class OllamaChat::Utils::ExconLogger
  # Standard Ruby Logger severity methods to intercept
  LOG_METHODS = %i[debug info warn error fatal unknown].freeze

  # Creates a new ExconLogger instance.
  #
  # @param chat [OllamaChat::Chat] the chat instance for logging
  def initialize(chat)
    @chat = chat
  end

  # Dynamically defines all standard logger severity methods to route
  # through the chat's logging system.
  #
  # @param message [String] the log message
  # @return [NilClass, TrueClass]
  LOG_METHODS.each do |method|
    define_method(method) do |message = nil, &block|
      msg = block&.(message) || message
      return unless msg

      @chat.log(:debug, "Excon", data: { method => msg })
      true
    end
  end

  # Stub for Logger#<<(not used by Excon LoggingInstrumentor).
  #
  # @param _message [String] the log message
  # @return [nil]
  def <<(_message)
    nil
  end
end
