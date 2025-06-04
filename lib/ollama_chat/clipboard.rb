module OllamaChat::Clipboard

  # Copy the last assistant's message to the system clipboard.
  #
  # This method checks if there is a last message from an assistant in the `@messages`
  # array and copies its content to the clipboard using the specified command from `config.copy`.
  # If no assistant response is available or the clipboard command is not found, appropriate
  # error messages are displayed.
  #
  # @return [NilClass] Always returns nil.
  def copy_to_clipboard
    if message = @messages.last and message.role == 'assistant'
      copy = `which #{config.copy}`.chomp
      if copy.present?
        IO.popen(copy, 'w') do |clipboard|
          clipboard.write(message.content)
        end
        STDOUT.puts "The last response has been copied to the system clipboard."
      else
        STDERR.puts "#{config.copy.inspect} command not found in system's path!"
      end
    else
      STDERR.puts "No response available to copy to the system clipboard."
    end
    nil
  end

  # Paste content from the input.
  #
  # Prompts the user to paste their content and then press C-d (Ctrl+D) to terminate
  # input. Reads all lines from standard input until Ctrl+D is pressed and returns
  # the pasted content as a string.
  #
  # @return [String] The pasted content entered by the user.
  def paste_from_input
    STDOUT.puts bold { "Paste your content and then press C-d!" }
    STDIN.read
  end
end
