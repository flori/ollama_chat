module OllamaChat::ServerSocket
  class << self
    # The send_to_server_socket method sends content to the server socket and returns
    # the response if type is :socket_input_with_response, otherwise it returns nil.

    # @param content [ String ] the message to be sent to the server
    # @param type [ Symbol ] the type of message being sent (default: :socket_input)
    #
    # @return [ String, NilClass ] the response from the server if type is
    #   :socket_input_with_response, otherwise nil.
    def send_to_server_socket(content, type: :socket_input)
      server = UnixSocks::Server.new(socket_name: 'ollama_chat.sock')
      message = { content:, type: }
      if type.to_sym == :socket_input_with_response
         return server.transmit_with_response(message)
      else
         server.transmit(message)
         nil
      end
    end
  end

  attr_accessor :server_socket_message

  # Initializes the server socket to receive messages from the Ollama Chat
  # Client.
  #
  # This method sets up a Unix domain socket server that listens for incoming
  # messages in the background. When a message is received, it updates the
  # instance variable `server_socket_message` and sends an interrupt signal
  # to the current process in order to handle the message.
  #
  # @return [ nil ] This method does not return any value, it only sets up the
  # server socket and kills the process when a message is received.
  def init_server_socket
    server = UnixSocks::Server.new(socket_name: 'ollama_chat.sock')
    server.receive_in_background do |message|
      self.server_socket_message = message
      Process.kill :INT, $$
    end
  end
end
