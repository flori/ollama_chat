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
  #   If nil or empty, defaults to a server name derived from the current
  #   working directory using {default_server_name}
  # @param clientserver [String] The clientserver protocol to use, defaults to
  #   'socket'
  #
  # @return [OllamaChat::Vim] A new Vim instance configured with the specified
  #   server name
  def initialize(server_name = nil, clientserver: nil)
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
      report_error(result) and return
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

  # The server_running? method checks if a Vim server is currently running and
  # accessible.
  #
  # This method determines whether a Vim server with the configured server name
  # is active by attempting to retrieve the current cursor column position. If
  # the column position is greater than zero, it indicates that Vim is running
  # and the server is accessible.
  #
  # @return [Boolean] true if the Vim server is running and accessible, false otherwise
  def server_running?
    col > 0
  end

  # The open_file method opens a file in Vim at a specified line and optionally
  # marks a range.
  #
  # This method sends a command to a running Vim server to open a file at a
  # given line number. If an end line is provided, it also marks the range
  # between start and end lines. The method ensures the Vim server is running
  # before attempting to send commands.
  #
  # @param file_path [ String ] the path to the file to be opened in Vim
  # @param start_line [ Integer ] the line number to start at (defaults to 1)
  # @param end_line [ Integer, nil ] the line number to end at, if marking a range
  #
  # @return [ OllamaChat::Vim, nil ] returns self if successful, nil if failed
  # @return [ nil ] returns nil if the Vim server is not running
  # @return [ nil ] returns nil if the system command fails
  def open_file(file_path, start_line = nil, end_line = nil)
    start_line ||= 1
    unless server_running?
      STDERR.puts <<~EOT
          Failed! Vim has to be running with server name "#@server_name"!
      EOT
      return
    end
    cmd = %{
      vim --clientserver "#@clientserver" --servername "#@server_name" --remote +#{start_line} "#{file_path}"
    }
    result = system(cmd)
    report_error(result) and return
    if end_line
      mark_range = "<ESC>:normal #{start_line}GV#{end_line}G<CR>"
      cmd = %{
        vim --clientserver "#@clientserver" --servername "#@server_name" --remote-send #{mark_range.inspect}
      }
      result = system(cmd)
      report_error(result) and return
    else
      center = "<ESC>zz"
      cmd = %{
        vim --clientserver "#@clientserver" --servername "#@server_name" --remote-send #{center.inspect}
      }
      result = system(cmd)
      report_error(result) and return
    end
    self
  end

  # The report_error method handles error reporting for Vim server operations.
  #
  # This method checks if a system command result indicates failure and outputs
  # an appropriate error message to standard error when the command fails.
  #
  # @param result [Boolean] the result of a system command execution
  #
  # @return [Boolean] returns true if the command failed, false otherwise
  # @return [Boolean] returns false if the command succeeded
  def report_error(result)
    unless result
      STDERR.puts <<~EOT
          Failed! vim is required in path and running with server name "#@server_name".
      EOT
      true
    end
    false
  end
end
