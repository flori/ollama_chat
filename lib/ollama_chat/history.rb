module OllamaChat::History
  def chat_history_filename
    File.expand_path(config.chat_history_filename)
  end

  def init_chat_history
    if File.exist?(chat_history_filename)
      File.open(chat_history_filename, ?r) do |history|
        history_data = JSON.load(history)
        clear_history
        Readline::HISTORY.push(*history_data)
      end
    end
  end

  def save_history
    File.secure_write(chat_history_filename, JSON.dump(Readline::HISTORY))
  end

  def clear_history
    Readline::HISTORY.clear
  end
end
