module OllamaChat::ServerSocket
  class << self
    # Returns the path to the XDG runtime directory, or a default path if not set.
    # @return [String] the expanded path to the XDG runtime directory
    def runtime_dir
      File.expand_path(ENV.fetch('XDG_RUNTIME_DIR',  '~/.local/run'))
    end

    # Constructs the full path to the server socket file.
    # @return [String] the full path to the Unix socket
    def server_socket_path
      File.join(runtime_dir, 'ollama_chat.sock')
    end

    # Sends a message to the server socket.
    #
    # @param content [String] the content to send
    # @param type [Symbol] the type of message (default: :socket_input)
    # @raise [Errno::ENOENT] if the socket file does not exist
    # @raise [Errno::ECONNREFUSED] if the socket is not listening (server no running)
    def send_to_server_socket(content, type: :socket_input)
      FileUtils.mkdir_p runtime_dir
      message = { content:, type: }
      socket = UNIXSocket.new(server_socket_path)
      socket.puts JSON(message)
      socket.close
    end
  end

  # Accessor for the server socket message.
  # Holds the last message received from the Unix socket.
  # @return [String, nil] the message content, or nil if not set
  # @see OllamaChat::ServerSocket#init_server_socket
  # @see OllamaChat::ServerSocket#send_to_server_socket
  attr_accessor :server_socket_message

  # Initializes a Unix domain socket server for OllamaChat.
  #
  # Creates the necessary runtime directory, checks for existing socket file,
  # and starts a server loop in a new thread. Listens for incoming connections,
  # reads JSON data, and terminates the server upon receiving a message.
  #
  # Raises Errno::EEXIST if the socket path already exists.
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
