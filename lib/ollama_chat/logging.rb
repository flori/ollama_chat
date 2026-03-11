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
end
