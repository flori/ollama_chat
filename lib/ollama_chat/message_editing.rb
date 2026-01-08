# A module that provides message editing functionality for OllamaChat.
#
# The MessageEditing module encapsulates methods for modifying existing chat
# messages using an external editor. It allows users to edit the last message
# in the conversation, whether it's a system prompt, user message, or assistant
# response.
module OllamaChat::MessageEditing
  # The revise_last method opens the last message in an external editor for
  # modification.
  #
  # This method retrieves the last message from the conversation, writes its
  # content to a temporary file, opens that file in the configured editor,
  # and then updates the message with the edited content upon successful
  # completion.
  #
  # @return [String, nil] the edited content if successful, nil otherwise
  def revise_last
    if message = @messages.last
      unless editor = OllamaChat::EnvConfig::EDITOR?
        STDERR.puts "Editor required for revise, set env var " \
          "#{OllamaChat::EnvConfig::EDITOR!.env_var.inspect}."
        return
      end

      Tempfile.open do |tmp|
        tmp.write(message.content)
        tmp.flush

        result = system %{#{editor} #{tmp.path.inspect}}

        if result
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
      STDERR.puts "No message available to revise."
    end
    nil
  end
end
