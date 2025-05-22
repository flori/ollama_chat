module OllamaChat::ServerSocket
  class << self
    def runtime_dir
      File.expand_path(ENV.fetch('XDG_RUNTIME_DIR',  '~/.local/run'))
    end

    def server_socket_path
      File.join(runtime_dir, 'ollama_chat.sock')
    end

    def send_to_server_socket(content)
      FileUtils.mkdir_p runtime_dir
      message = { content: }
      socket = UNIXSocket.new(server_socket_path)
      socket.puts JSON(message)
      socket.close
    end
  end

  attr_accessor :server_socket_message

  def init_server_socket
    FileUtils.mkdir_p OllamaChat::ServerSocket.runtime_dir
    if File.exist?(OllamaChat::ServerSocket.server_socket_path)
      raise Errno::EEXIST, "Path already exists #{OllamaChat::ServerSocket.server_socket_path.inspect}"
    end
    Thread.new do
      Socket.unix_server_loop(OllamaChat::ServerSocket.server_socket_path) do |sock, client_addrinfo|
        begin
          data = sock.readline.chomp
          self.server_socket_message = JSON.load(data)
          Process.kill :INT, $$
        rescue JSON::ParserError
        ensure
          sock.close
        end
      end
    rescue Errno::ENOENT
    ensure
      FileUtils.rm_f OllamaChat::ServerSocket.server_socket_path
    end
  end
end
