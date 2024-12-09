module OllamaChat::MessageType
  def message_type(images)
    images.present? ? ?📸 : ?📨
  end
end
