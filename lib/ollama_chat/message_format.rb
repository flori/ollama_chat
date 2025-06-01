module OllamaChat::MessageFormat
  def message_type(images)
    images.present? ? ?📸 : ?📨
  end

  def think_annotate(&block)
    string = block.()
    string.to_s.size == 0 and return
    if @chat.think.on?
      "💭\n#{string}\n"
    end
  end

  def talk_annotate(&block)
    string = block.()
    string.to_s.size == 0 and return
    if @chat.think.on?
      "💬\n#{string}\n"
    else
      string
    end
  end
end
