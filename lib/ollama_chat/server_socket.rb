require 'digest/md5'
require 'fileutils'

# A module that provides server socket functionality for OllamaChat
#
# The ServerSocket module encapsulates the logic for creating and managing Unix
# domain socket servers that enable external processes to send input to running
# ollama_chat sessions. It supports both simple message transmission and
# bidirectional communication with response handling, allowing for integration
# with tools like ollama_chat_send.
#
# @example Sending a message to a running chat session
#   OllamaChat::ServerSocket.send_to_server_socket(
#     "Hello from external process",
#     config: chat_config,
#     type: :socket_input
#   )
#
# @example Sending a message and waiting for a response
#   response = OllamaChat::ServerSocket.send_to_server_socket(
#     "What is the answer?",
#     config: chat_config,
#     type: :socket_input_with_response,
#     parse: true
#   )
module OllamaChat::ServerSocket
  class << self
    # The send_to_server_socket method transmits a message to a Unix domain
    # socket server for processing by the Ollama Chat client.
    #
    # This method creates a socket server instance using the provided
    # configuration, prepares a message with the given content, type, and parse
    # flag, then sends it either as a simple transmission or with a response
    # expectation depending on the message type. It is used to enable
    # communication between external processes and the chat session via a named
    # Unix socket.
    #
    # @param content [ String ] the message content to be sent
    # @param config [ ComplexConfig::Settings ] the configuration object containing server settings
    # @param type [ Symbol ] the type of message transmission, defaults to :socket_input
    # @param runtime_dir [ String ] pathname to runtime_dir of socket file
    # @param working_dir [ String ] pathname to working_dir used for deriving socket file
    # @param parse [ TrueClass, FalseClass ] whether to parse the response, defaults to false
    #
    # @return [ UnixSocks::Message, nil ] the response from transmit_with_response if type
    # is :socket_input_with_response, otherwise nil
    def send_to_server_socket(content, config:, type: :socket_input, runtime_dir: nil, working_dir: nil, parse: false)
      server  = create_socket_server(config:, runtime_dir:, working_dir:)
      message = { content:, type:, parse: }
      if type.to_sym == :socket_input_with_response
        server.transmit_with_response(message)
      else
        server.transmit(message)
        nil
      end
    end

    # The create_socket_server method constructs and returns a Unix domain
    # socket server instance for communication with the Ollama Chat client.
    #
    # This method initializes a UnixSocks::Server object configured to listen
    # for incoming messages on a named socket file. It supports specifying a
    # custom runtime directory for the socket, which is useful for isolating
    # multiple instances or environments. If no runtime directory is provided
    # in the configuration, it defaults to using the standard system location
    # for Unix domain sockets.
    #
    # @param config [ComplexConfig::Settings] the configuration object
    # containing server settings
    # @param runtime_dir [ String ] pathname to runtime_dir of socket file
    # @param working_dir [ String ] pathname to working_dir used for deriving socket file
    #
    # @return [UnixSocks::Server] a configured Unix domain socket server
    # instance ready to receive messages
    def create_socket_server(config:, runtime_dir: nil, working_dir: nil)
      working_dir ||= Dir.pwd
      if runtime_dir
        return UnixSocks::Server.new(socket_name: 'ollama_chat.sock', runtime_dir:)
      end
      if config.working_dir_dependent_socket
        path   = File.expand_path(working_dir)
        digest = Digest::MD5.hexdigest(path)
        UnixSocks::Server.new(socket_name: "ollama_chat-#{digest}.sock")
      else
        UnixSocks::Server.new(socket_name: 'ollama_chat.sock')
      end
    end
  end

  # The server_socket_message accessor method provides read and write access to
  # the server socket message instance variable.
  #
  # @return [ Object, nil ] the current server socket message object or nil if
  # not set
  attr_accessor :server_socket_message

  # Initializes the server socket to receive messages from the Ollama Chat
  # Client.
  #
  # This method sets up a Unix domain socket server that listens for incoming
  # messages in the background. When a message is received, it updates the
  # instance variable `server_socket_message` and sends an interrupt signal
  # to the current process in order to handle the message.
  def init_server_socket
    server = OllamaChat::ServerSocket.create_socket_server(config:)
    server.receive_in_background do |message|
      self.server_socket_message = message
      Process.kill :INT, $$
    end
  rescue Errno::EEXIST
    socket_path = server.server_socket_path
    STDERR.puts <<~EOT
      Warning! Socket file exists at: #{socket_path}
      This may indicate that another #{File.basename($0)} process is already
      running using the same directory or that a previous process left a stale
      socket file.
    EOT
    if ask?(prompt: 'Do you want to remove the existing socket file and continue? (y/n) ') =~ /\Ay/i
      FileUtils.rm_f socket_path
      retry
    else
      exit 1
    end
  end
end
