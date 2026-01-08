require 'tempfile'

# A class that provides functionality for inserting text into Vim buffers via
# remote communication.
#
# @example
#   vim = OllamaChat::Vim.new("MY_SERVER")
#   vim.insert("Hello, Vim!")
class OllamaChat::Vim
  # Initializes a new Vim server connection
  #
  # Creates a new OllamaChat::Vim instance for interacting with a specific Vim
  # server. If no server name is provided, it derives a standardized server
  # name based on the current working directory using the default_server_name
  # method.
  #
  # @param server_name [String, nil] The name of the Vim server to connect to.
  #   If nil or empty, defaults to a server name derived from the current working
  #   directory using {default_server_name}
  # @param clientserver [String] The clientserver protocol to use, defaults to 'socket'
  #
  # @return [OllamaChat::Vim] A new Vim instance configured with the specified
  #   server name
  def initialize(server_name, clientserver: nil)
    server_name.full? or server_name = self.class.default_server_name
    @server_name  = server_name
    @clientserver = clientserver || 'socket'
  end

  # The server_name attribute reader returns the name of the Vim server to
  # connect to.
  #
  # @return [ String ] the name of the Vim server
  attr_reader :server_name

  # The clientserver attribute reader returns the clientserver protocol to be
  # used.
  #
  # @return [ String ] the clientserver protocol identifier
  attr_reader :clientserver

  # The default_server_name method generates a standardized server name
  # based on a given name or the current working directory.
  #
  # This method creates a unique server identifier by combining the basename
  # of the provided name (or current working directory) with a truncated
  # MD5 hash digest of the full path. The resulting name is converted to
  # uppercase for consistent formatting.
  #
  # @param name [ String ] the base name to use for server identification
  #   defaults to the current working directory
  #
  # @return [ String ] a formatted server name suitable for use with Vim
  #   server connections
  def self.default_server_name(name = Dir.pwd)
    prefix = File.basename(name)
    suffix = Digest::MD5.hexdigest(name)[0, 8]
    name = [ prefix, suffix ] * ?-
    name.upcase
  end

  # Inserts text at the current cursor position in Vim
  #
  # This method writes the provided text to a temporary file and uses Vim's
  # remote-send functionality to insert it at the current cursor position.
  # The text is automatically indented to match the current column position.
  #
  # @param text [String] The text to be inserted into the Vim buffer
  # @return [OllamaChat::Vim, nil] Returns self if successful or nil.
  def insert(text)
    spaces = (col - 1).clamp(0..)
    text   = text.gsub(/^/, ' ' * spaces)
    Tempfile.open do |tmp|
      tmp.write(text)
      tmp.flush
      result = system %{
        vim --clientserver "#@clientserver" --servername "#@server_name" --remote-send "<ESC>:r #{tmp.path}<CR>"
      }
      unless result
        STDERR.puts "Failed! vim is required in path."
        return
      end
    end
    self
  end

  # Returns the current column position of the cursor in the Vim server
  #
  # This method queries the specified Vim server for the current cursor position
  # using Vim's remote expression feature. It executes a Vim command that returns
  # the result of `col('.')`, which represents the current column number (1-indexed)
  # of the cursor position.
  def col
    `vim --clientserver "#@clientserver" --servername "#@server_name" --remote-expr "col('.')"`.chomp.to_i
  end
end
