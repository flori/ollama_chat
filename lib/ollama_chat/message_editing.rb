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
      edit_text_block(message.content) do |tmp|
        if result = edit_file(tmp.path)
          new_content           = File.read(tmp.path)
          old_message           = @messages.messages.pop.as_json
          old_message[:content] = new_content
          @messages << OllamaChat::Message.from_hash(old_message)
          feedback("Message edited and updated.", type: :info)
          return new_content
        else
          feedback("Editor failed to edit message.", type: :warn)
        end
      end
    else
      feedback("No message available to change.", type: :warn)
    end
    nil
  end
end
