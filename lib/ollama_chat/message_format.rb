# A module that provides formatting functionality for chat messages.
#
# The MessageFormat module encapsulates methods for determining message icons
# based on whether images are present, and for conditionally annotating content
# with thinking or talk indicators. It supports customizable formatting of
# message text for display in terminal interfaces.
#
# @example Using message_type to determine icon based on images
#   message_type([])        # => "📨"
#   message_type(["image"]) # => "📸"
#
# @example Annotating content with thinking indicator
#   think_annotate { "Thinking..." } # => "💭\nThinking...\n" (when think is enabled)
#
# @example Annotating content with talk indicator
#   talk_annotate { "Speaking..." } # => "💬\nSpeaking...\n" (when think is enabled)
module OllamaChat::MessageFormat
  # Returns the terminal color code associated with the message's role.
  #
  # @param message [ OllamaChat::Message ] the message object to determine the color for
  # @return [ Integer ] the color code corresponding to the role
  def role_color(message)
    case message.role
    when 'user'      then 172
    when 'assistant' then 111
    when 'system'    then 213
    else                  210
    end
  end

  # Returns the formatting template for the message sender's role.
  #
  # The template is retrieved from the chat configuration based on the
  # message's role.
  # If no specific template is found for the role, it falls back to the default
  # role template.
  #
  # @param message [ OllamaChat::Message ] the message object
  # @return [ String ] the formatting template string
  def role_template(message)
    chat.config.roles[message.role] || chat.config.roles.default
  end

  # Returns the display name for the message sender.
  #
  # If a full sender name is available, it returns either the formatted
  # template or the raw name based on the `template` parameter.
  # Otherwise, it returns the message role.
  #
  # @param message [ OllamaChat::Message ] the message object
  # @param template [ Boolean ] whether to apply the role formatting template (default: true)
  # @return [ String ] the formatted sender name, the raw name, or the role
  def sender_name_displayed(message, template: true)
    if sender_name = message.ask_and_send(:sender_name).full?
      if template
        role_template(message) % { sender_name: }
      else
        sender_name
      end
    else
      message.role
    end
  end

  # Formats the sender's identity for display in the terminal, including
  # the message icon and the sender's name or role with appropriate coloring.
  #
  # @param message [ OllamaChat::Message ] the message object to format
  # @return [ String ] the formatted string representing the sender
  def display_sender(message)
    color = role_color(message)
    name  = sender_name_displayed(message)
    message_type(message.images) + " " + bold { color(color) { name } }
  end

  # The message_type method determines the appropriate message icon based on
  # whether images are present.
  #
  # @param images [ Array ] an array of images
  #
  # @return [ String ] returns 📸 if images are present, 📨 otherwise
  def message_type(images)
    images.present? ? ?📸 : ?📨
  end

  # Returns the current chat context.
  #
  # This method ensures that the formatting logic has access to the chat's
  # configuration (e.g., whether 'think_loud' is enabled). It returns `self`
  # if the object is already a `OllamaChat::Chat` instance, otherwise it
  # returns the `@chat` instance variable.
  #
  # @return [ OllamaChat::Chat ] the chat context
  def chat
    self.is_a?(OllamaChat::Chat) ? self : @chat
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
    if chat.think_loud?
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
    if chat.think_loud?
      "💬\n#{string}\n"
    else
      string
    end
  end
end
