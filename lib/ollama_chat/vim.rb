require 'tempfile'
require 'pathname'

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
  # server. If no server name is provided, it defaults to using the current
  # working directory as the server identifier.
  #
  # @param server_name [String, nil] The name of the Vim server to connect to.
  #  If nil or empty, defaults to the current working directory path in
  #  uppercase
  def initialize(server_name)
    server_name.full? or server_name = default_server_name
    @server_name = server_name
  end

  # The default server name is derived from the current working directory It
  # converts the absolute path to uppercase for consistent identification This
  # approach ensures each working directory gets a unique server identifier The
  # server name format makes it easy to distinguish different Vim sessions
  def default_server_name
    Pathname.pwd.to_s.upcase
  end

  # Inserts text at the current cursor position in Vim
  #
  # This method writes the provided text to a temporary file and uses Vim's
  # remote-send functionality to insert it at the current cursor position.
  # The text is automatically indented to match the current column position.
  #
  # @param text [String] The text to be inserted into the Vim buffer
  def insert(text)
    spaces = (col - 1).clamp(0..)
    text   = text.gsub(/^/, ' ' * spaces)
    Tempfile.open do |tmp|
      tmp.write(text)
      tmp.flush
      system %{vim --servername "#@server_name" --remote-send "<ESC>:r #{tmp.path}<CR>"}
    end
  end

  # Returns the current column position of the cursor in the Vim server
  #
  # This method queries the specified Vim server for the current cursor position
  # using Vim's remote expression feature. It executes a Vim command that returns
  # the result of `col('.')`, which represents the current column number (1-indexed)
  # of the cursor position.
  def col
    `vim --servername "#@server_name" --remote-expr "col('.')"`.chomp.to_i
  end
end
