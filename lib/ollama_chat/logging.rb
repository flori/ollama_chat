# Provides a simple logging facility for the OllamaChat application. It offers
# methods to access a logger, determine the current log level, and write
# messages at various severity levels, including debug.
module OllamaChat::Logging
  # The logger method returns the current Logger instance used by OllamaChat.
  # If no Logger exists, it creates one pointing to the configured log file.
  #
  # @return [Logger] the active Logger instance
  def logger
    @logger ||= begin
      OC::OLLAMA::CHAT::LOGFILE.dirname.mkpath
      l = Logger.new(OC::OLLAMA::CHAT::LOGFILE)
      l.formatter = -> (severity, time, _progname, msg) do
        msg = msg.stringify_keys_recursive
        msg['level']    = severity
        msg['time']     = time.iso8601(0)
        msg['progname'] = progname
        msg.to_json + "\n"
      end
      l
    end
  end

  # The log method records a message or exception at the specified severity
  # level using the logger and optionally triggers a warning output
  #
  # @param severity [ Symbol ] the logging level to use
  # @param msg [ String, Exception ] the message or exception to be logged
  # @param warn [ TrueClass, FalseClass ] whether to also trigger a warning output
  def log(severity, msg, data: nil, warn: false)
    payload = {
      msg:   ,
      data:  data || {}
    }

    if msg.is_a?(Exception)
      payload[:msg] = msg = "#{msg.class}: #{msg.message}"
      payload[:data][:backtrace] = msg.ask_and_send(:backtrace)
    else
      payload[:msg] = msg.to_s
    end

    logger.send(severity, payload)
    warn and self.warn(msg)
    nil
  end
end
