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
  # @param content [Boolean] If true, copies the content of the message;
  #   if false, copies the entire message object (default: false)
  #
  # @raise [OllamaChat::OllamaChatError] if the clipboard command specified
  #   in config.copy is not found in the system's PATH
  # @raise [OllamaChat::OllamaChatError] if no assistant message is available
  #   to copy to the clipboard
  def perform_copy_to_clipboard(content: false)
    if message = @messages.find_last(content:) { _1.role == 'assistant' }
      copy = `which #{config.copy}`.chomp
      if copy.present?
        IO.popen(copy, 'w') do |clipboard|
          clipboard.write(message.content)
        end
      else
        raise OllamaChat::OllamaChatError, "#{config.copy.inspect} command not found in system's path!"
      end
    else
      raise OllamaChat::OllamaChatError, "No response available to copy to the system clipboard."
    end
  end

  private

  # Copies the last assistant message to the system clipboard.
  #
  # This method is the interface for copying assistant messages to the
  # clipboard in the chat. It calls perform_copy_to_clipboard internally and
  # handles any OllamaChat::OllamaChatError exceptions by printing the error
  # message to standard error and does not re-raise the exception.
  #
  # @example Copying the last response to clipboard
  #   chat.copy_to_clipboard
  def copy_to_clipboard
    perform_copy_to_clipboard
    STDOUT.puts "The last response has been successfully copied to the system clipboard."
  rescue OllamaChat::OllamaChatError => e
    STDERR.puts e.message
  end

  # Paste content from the input.
  #
  # Prompts the user to paste their content and then press C-d (Ctrl+D) to
  # terminate input. Reads all lines from standard input until Ctrl+D is
  # pressed and returns the pasted content as a string.
  #
  # @return [String] The pasted content entered by the user.
  def paste_from_input
    STDOUT.puts bold { "Paste your content and then press C-d!" }
    STDIN.read
  end
end
