module OllamaChat::Clipboard
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

  def paste_from_input
    STDOUT.puts bold { "Paste your content and then press C-d!" }
    STDIN.read
  end
end
