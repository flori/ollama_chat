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
  private

  # The init_chat_history method initializes the chat session by loading
  # previously saved command history from a JSON or JSONL file.
  #
  # This method checks for the existence of a chat history file and, if found,
  # loads its contents into the Readline::HISTORY array. It clears the current
  # history and replaces it with the saved history data. Any errors during the
  # loading process are caught and logged as warnings, but do not interrupt the
  # execution flow.
  def init_chat_history
    if OC::OLLAMA::CHAT::HISTORY.exist?
      if OC::OLLAMA::CHAT::HISTORY.extname == '.jsonl'
        history_data = OC::OLLAMA::CHAT::HISTORY.each_line.map { JSON.load(_1) }
      else
        history_data = JSON.load(OC::OLLAMA::CHAT::HISTORY.read)
      end
      Readline::HISTORY.clear
      Readline::HISTORY.push(*history_data)
    end
  rescue => e
    msg = "Caught #{e.class} while loading #{OC::OLLAMA::CHAT::HISTORY.inspect}: #{e}"
    log(:error, msg, warn: true)
  end

  # The save_history method persists the current command history to a file.
  #
  # This method serializes the Readline::HISTORY array into JSON or JSONL
  # format and writes it to the chat history filename. It handles potential
  # errors during the write operation by catching exceptions and issuing a
  # warning message.
  def save_history
    File.secure_write(OC::OLLAMA::CHAT::HISTORY) do |out|
      if OC::OLLAMA::CHAT::HISTORY.extname == '.jsonl'
        Readline::HISTORY.each { out.puts JSON.dump(_1) }
      else
        out.write JSON.dump(Readline::HISTORY)
      end
    end
  rescue => e
    msg = "Caught #{e.class} while saving #{OC::OLLAMA::CHAT::HISTORY.inspect}: #{e}"
    log(:error, msg, warn: true)
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
