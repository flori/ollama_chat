# Provides a simple logging facility for the OllamaChat application. It offers
# methods to access a logger, determine the current log level, and write
# messages at various severity levels, including debug.
module OllamaChat::Logging
  # The logger method returns the current Logger instance used by OllamaChat.
  # If no Logger exists, it creates one pointing to the configured log file.
  #
  # @return [Logger] the active Logger instance
  def logger
    @logger and return @logger
    OC::OLLAMA::CHAT::LOGFILE.dirname.mkpath
    @logger = Logger.new(OC::OLLAMA::CHAT::LOGFILE)
  end

  # The log method records a message or exception at the specified severity
  # level using the logger and optionally triggers a warning output
  #
  # @param severity [ Symbol ] the logging level to use
  # @param msg [ String, Exception ] the message or exception to be logged
  # @param warn [ TrueClass, FalseClass ] whether to also trigger a warning output
  def log(severity, msg, warn: false)
    if msg.is_a?(Exception)
      msg = "Caught #{msg.class}: #{msg}\n#{Array(msg&.backtrace).join(?\n)}"
    end
    logger.send(severity, msg)
    warn and self.warn(msg)
    nil
  end
end
