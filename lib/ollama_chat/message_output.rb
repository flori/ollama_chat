module OllamaChat::MessageOutput
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

  def output(filename)
    if message = @messages.last and message.role == 'assistant'
      begin
        write_file_unless_exist(filename)
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

  def write_file_unless_exist(filename)
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
