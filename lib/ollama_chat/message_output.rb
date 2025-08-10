module OllamaChat::MessageOutput
  # The pipe method forwards the last assistant message to a command's standard
  # input.
  #
  # @param cmd [ String ] the command to which the output should be piped
  #
  # @return [ OllamaChat::Chat ] returns self
  # @return [ nil ] returns nil if the command is not provided or if there is
  # no assistant message
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
  # @param filename [ String ] the path to the file where the output should be written
  #
  # @return [ Chat ] returns self on success, nil on failure
  #
  # @see write_file_unless_exist
  #
  # @note If no assistant message is available, an error message is printed to stderr.
  def output(filename)
    if message = @messages.last and message.role == 'assistant'
      begin
        write_file_unless_exist(filename, message)
        STDOUT.puts "Last response was written to #{filename.inspect}."
        self
      rescue => e
        STDERR.puts "Writing to #{filename.inspect}, caused #{e.class}: #{e}."
      end
    else
      STDERR.puts "No response available to write to #{filename.inspect}."
    end
  end

  private

  # The write_file_unless_exist method creates a new file with the specified
  # message content, but only if a file with that name does not already exist.
  #
  # @param filename [ String ] the path of the file to be created
  # @param message [ Ollama::Message ] the message object containing the content to write
  #
  # @return [ TrueClass ] if the file was successfully created
  # @return [ nil ] if the file already exists and was not created
  def write_file_unless_exist(filename, message)
    if File.exist?(filename)
      STDERR.puts "File #{filename.inspect} already exists. Choose another filename."
      return
    end
    File.open(filename, ?w) do |output|
      output.write(message.content)
    end
    true
  end
end
