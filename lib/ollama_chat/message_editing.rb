# A module that provides message editing functionality for OllamaChat.
#
# The MessageEditing module encapsulates methods for modifying existing chat
# messages using an external editor.
module OllamaChat::MessageEditing
  private

  # The change_response method opens the last message (usually the assistant's
  # response) in an external editor for modification.
  #
  # This method retrieves the last message from the conversation, writes its
  # content to a temporary file, opens that file in the configured editor,
  # and then updates the message with the edited content upon successful
  # completion.
  #
  # @return [String, nil] the edited content if successful, nil otherwise
  def change_response
    if message = @messages.last
      Tempfile.open do |tmp|
        tmp.write(message.content)
        tmp.flush

        if result = edit_file(tmp.path)
          new_content           = File.read(tmp.path)
          old_message           = @messages.messages.pop.as_json
          old_message[:content] = new_content
          @messages << Ollama::Message.from_hash(old_message)
          STDOUT.puts "Message edited and updated."
          return new_content
        else
          STDERR.puts "Editor failed to edit message."
        end
      end
    else
      STDERR.puts "No message available to change."
    end
    nil
  end
end
