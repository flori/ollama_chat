module OllamaChat::MessageFormat
  # The message_type method determines the appropriate message icon based on
  # whether images are present.
  #
  # @param images [ Array ] an array of images
  #
  # @return [ String ] returns 📸 if images are present, 📨 otherwise
  def message_type(images)
    images.present? ? ?📸 : ?📨
  end

  # The think_annotate method processes a string and conditionally annotates it
  # with a thinking emoji if the think feature is enabled.
  #
  # @param block [ Proc ] a block that returns a string to be processed
  #
  # @return [ String, nil ] the annotated string with a thinking emoji if enabled, otherwise nil
  def think_annotate(&block)
    string = block.()
    string.to_s.size == 0 and return
    if @chat.think.on?
      "💭\n#{string}\n"
    end
  end

  # The talk_annotate method processes a string output by a block and
  # conditionally adds annotation.
  #
  # @param block [ Proc ] a block that returns a string to be processed
  #
  # @return [ String, nil ] the annotated string if it has content, otherwise nil
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
