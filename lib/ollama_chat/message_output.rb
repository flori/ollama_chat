# A module that provides output functionality for chat messages.
#
# This module encapsulates methods for piping assistant responses to command
# standard input and writing assistant responses to files. It handles the
# mechanics of sending output to external processes or saving content to disk
# while providing appropriate error handling and user message.
#
# @example Piping a response to a command
#   chat.pipe('cat > output.txt')
#
# @example Writing a response to a file
#   chat.output('response.txt')
module OllamaChat::MessageOutput
  # The pipe method forwards the last assistant message to a command's standard
  # input.
  #
  # @param cmd [ String ] the command to which the output should be piped
  #
  # @return [ OllamaChat::Chat ] returns self
  # @return [ nil ] returns nil if the command is not provided or if there is
  #   no assistant message
  def pipe(cmd)
    cmd.present? or return
    if message = @messages.last and message.role == 'assistant'
      begin
        IO.popen(cmd, ?w) do |output|
          output.write(message.content)
        end
        exit_code = $?&.exitstatus
        if exit_code == 0
          STDOUT.puts "Last response was piped to #{cmd.inspect}."
        else
          STDERR.puts "Executing #{cmd.inspect}, failed with exit code #{exit_code}."
        end
        self
      rescue => e
        STDERR.puts "Executing #{cmd.inspect}, caused #{e.class}: #{e}."
      end
    else
      STDERR.puts "No response available to output to pipe command #{cmd.inspect}."
    end
  end

  # The output method writes the last assistant message to a file.
  #
  # @param filename [ String ] the path to the file where the last assistant
  #   message should be written
  # @param edit [ Boolean ] whether to edit the content before saving (defaults to false)
  #
  # @return [ OllamaChat::Chat ] returns self
  def output(filename, edit: false)
    if message = @messages.last and message.role == 'assistant'
      and content = message.content
    then
      begin
        content = edit_text(content) if edit
        if attempt_to_write_file(filename, content)
          STDOUT.puts "Last response was written to #{filename.inspect}."
        end
        self
      rescue => e
        STDERR.puts "Writing to #{filename.inspect}, caused #{e.class}: #{e}."
      end
    else
      STDERR.puts "No response available to write to #{filename.inspect}."
    end
  end

  private

  # The attempt_to_write_file method handles writing content to a file with
  # overwrite confirmation.
  #
  # This method checks if a file already exists and prompts the user for
  # confirmation before overwriting it. If the user declines or if the file
  # doesn't exist, the method returns early without writing. Otherwise, it
  # opens the file in write mode and writes the message content to it.
  #
  # @param filename [ String ] the path to the file where the content should be
  #   written
  # @param content [ String ] the actual text content to be written to the file
  #
  # @return [ TrueClass ] returns true if the file was successfully written
  # @return [ nil ] returns nil if the user chose not to overwrite or if an
  #   error occurred
  def attempt_to_write_file(filename, content)
    path = Pathname.new(filename.to_s).expand_path
    if !path.exist? ||
        confirm?(
          prompt: "🔔 File #{path.to_s.inspect} already exists, overwrite? (y/n) ",
          yes: /\Ay/i
        )
    then
      File.open(path, ?w) do |output|
        output.write(content)
      end
    else
      return
    end
    true
  end
end
