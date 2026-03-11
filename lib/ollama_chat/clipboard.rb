# A module that provides clipboard functionality for copying and pasting chat
# messages.
#
# This module enables users to copy the last assistant message to the system
# clipboard and paste content from input, facilitating easy transfer of
# conversation content between different applications and contexts.
module OllamaChat::Clipboard
  # Copies the last assistant message to the system clipboard.
  #
  # This method finds the most recent message from the assistant and writes
  # its content to the system clipboard using the command specified in
  # the configuration (config.copy).
  #
  # @param content [true, false] If true, copies the content of the message;
  #   if false, copies the entire message object (default: false)
  #
  # @raise [OllamaChat::OllamaChatError] if the clipboard command specified
  #   in config.copy is not found in the system's PATH
  # @raise [OllamaChat::OllamaChatError] if no assistant message is available
  #   to copy to the clipboard
  def perform_copy_to_clipboard(text: nil, content: false)
    text ||= last_message_content(content:)
    if text
      copy = `which #{config.copy}`.chomp
      if copy.present?
        IO.popen(copy, 'w') do |clipboard|
          clipboard.write(text)
        end
        true
      else
        raise OllamaChat::OllamaChatError,
          "#{config.copy.inspect} command not found in system's path!"
      end
    else
      raise OllamaChat::OllamaChatError,
        "No text available to copy to the system clipboard."
    end
  end

  # Performs the actual clipboard paste operation.
  #
  # This method executes the configured clipboard paste command to retrieve
  # content from the system clipboard. It uses the command specified in the
  # configuration (`config.paste`) to fetch clipboard content.
  #
  # @return [String] The content retrieved from the system clipboard
  # @raise [OllamaChat::OllamaChatError] if the clipboard command is not found
  #   or if there is no content available to paste
  #
  # @example
  #   # Assuming config.paste is "pfc"
  #   content = perform_paste_from_clipboard
  #   # => "Some content from clipboard"
  def perform_paste_from_clipboard
    paste = `which #{config.paste}`.chomp
    if paste.present?
      IO.popen(paste, 'r') do |clipboard|
        text = clipboard.read
        if text.empty?
          raise OllamaChat::OllamaChatError,
            "No content available to paste from the system clipboard."
        else
          return text
        end
      end
    else
      raise OllamaChat::OllamaChatError,
        "#{config.paste.inspect} command not found in system's path!"
    end
  end

  private

  # Returns the content of the last assistant message.
  #
  # This private helper method finds the most recent message from the assistant
  # in the messages array and returns its content. It is used by
  # `perform_copy_to_clipboard` when no custom text is provided.
  #
  # @param content [true, false] If true, returns the content of the message;
  #   if false, returns nil if no assistant message is found (default: false)
  #
  # @return [String, nil] The content of the last assistant message, or nil if
  #   no assistant message is found
  #
  # @example
  #   # Assuming @messages contains assistant messages
  #   last_message_content
  #   # => "This is the last assistant response"
  def last_message_content(content: false)
    @messages.find_last(content:) { _1.role == 'assistant' }&.content
  end

  # Copies the last assistant message to the system clipboard.
  #
  # This method is the interface for copying assistant messages to the
  # clipboard in the chat. It calls perform_copy_to_clipboard internally and
  # handles any OllamaChat::OllamaChatError exceptions by printing the error
  # message to standard error and does not re-raise the exception.
  def copy_to_clipboard
    perform_copy_to_clipboard
    STDOUT.puts "The last response has been successfully copied to the system clipboard."
    true
  rescue OllamaChat::OllamaChatError => e
    STDERR.puts e.message
  end

  # Pastes content from the system clipboard into the chat.
  #
  # This method retrieves content from the system clipboard using the
  # configured paste command and integrates it into the chat session. It
  # handles clipboard errors gracefully by displaying error messages to
  # standard error.
  def paste_from_clipboard
    result = perform_paste_from_clipboard
    STDOUT.puts "The clipboard content has been successfully copied to the chat."
    result
  rescue OllamaChat::OllamaChatError => e
    STDERR.puts e.message
  end
end
