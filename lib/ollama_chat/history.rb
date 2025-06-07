module OllamaChat::History
  # Returns the full path of the chat history filename based on the
  # configuration.
  def chat_history_filename
    File.expand_path(config.chat_history_filename)
  end

  # Initializes the chat history by loading it from a file if it exists, and
  # then loads the history into Readline::HISTORY.
  def init_chat_history
    if File.exist?(chat_history_filename)
      File.open(chat_history_filename, ?r) do |history|
        history_data = JSON.load(history)
        clear_history
        Readline::HISTORY.push(*history_data)
      end
    end
  end

  # Saves the current chat history to a file in JSON format.
  def save_history
    File.secure_write(chat_history_filename, JSON.dump(Readline::HISTORY))
  end

  # Clears all entries from Readline::HISTORY.
  def clear_history
    Readline::HISTORY.clear
  end
end
