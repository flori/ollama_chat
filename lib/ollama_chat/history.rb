# A module that provides history management functionality for OllamaChat
# sessions.
#
# The History module encapsulates methods for initializing, saving, and
# clearing command-line history within the OllamaChat application. It handles
# persistence of user input history to a file and ensures that chat sessions
# can maintain state across invocations by loading previous command histories.
#
# @example Initializing chat history
#   chat.init_chat_history
#
# @example Saving chat history
#   chat.save_history
#
# @example Clearing chat history
#   chat.clear_history
module OllamaChat::History
  # The chat_history_filename method constructs and returns the full file path
  # for the chat history file.
  #
  # This method takes the configured chat history filename from the
  # configuration and expands it to an absolute path using File.expand_path.
  # This ensures that the returned path is fully qualified and can be used
  # reliably for reading from or writing to the chat history file.
  #
  # @return [String] the absolute file path to the chat history file as
  # specified in the configuration
  def chat_history_filename
    File.expand_path(OllamaChat::EnvConfig::OLLAMA::CHAT::HISTORY)
  end

  # The init_chat_history method initializes the chat session by loading
  # previously saved command history from a file.
  #
  # This method checks for the existence of a chat history file and, if found,
  # loads its contents into the Readline::HISTORY array. It clears the current
  # history and replaces it with the saved history data. Any errors during the
  # loading process are caught and logged as warnings, but do not interrupt the
  # execution flow.
  def init_chat_history
    if File.exist?(chat_history_filename)
      File.open(chat_history_filename, ?r) do |history|
        history_data = JSON.load(history)
        Readline::HISTORY.clear
        Readline::HISTORY.push(*history_data)
      end
    end
  rescue => e
    warn "Caught #{e.class} while loading #{chat_history_filename.inspect}: #{e}"
  end

  # The save_history method persists the current command history to a file.
  #
  # This method serializes the Readline::HISTORY array into JSON format and
  # writes it to the chat history filename. It handles potential errors during
  # the write operation by catching exceptions and issuing a warning message.
  def save_history
    File.secure_write(chat_history_filename, JSON.dump(Readline::HISTORY))
  rescue => e
    warn "Caught #{e.class} while saving #{chat_history_filename.inspect}: #{e}"
  end

  # The clear_history method clears the Readline history array and ensures that
  # the chat history is saved afterwards.
  #
  # This method removes all entries from the Readline::HISTORY array,
  # effectively clearing the command history maintained by the readline
  # library. It then calls save_history to persist this cleared state to the
  # configured history file. The method uses an ensure block to guarantee that
  # save_history is called even if an exception occurs during the clearing
  # process.
  def clear_history
    Readline::HISTORY.clear
  ensure
    save_history
  end
end
