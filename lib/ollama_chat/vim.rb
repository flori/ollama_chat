require 'tempfile'
require 'open3'

# A class that provides functionality for inserting text into Vim buffers via
# remote communication.
#
# @example
#   vim = OllamaChat::Vim.new("MY_SERVER")
#   vim.insert("Hello, Vim!")
class OllamaChat::Vim
  # Result of a vim client command execution.
  class Result < Data.define(:status, :stderr, :stdout)
    # @!attribute status
    #   @return [Process::Status] the exit status of the command
    # @!attribute stderr
    #   @return [String] stderr output from the command
    # @!attribute stdout
    #   @return [String, nil] stdout output, only when explicitly requested
  end

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

  # Inserts text at the current cursor position in Vim.
  #
  # Writes the provided text to a temporary file and uses Vim's
  # remote-send functionality to insert it at the current cursor position.
  # The text is automatically indented to match the current column position.
  #
  # @param text [String] The text to be inserted into the Vim buffer
  # @return [Result] the command result
  def insert(text)
    spaces = (col.stdout.to_i - 1).clamp(0..)
    text   = text.gsub(/^/, ' ' * spaces)
    Tempfile.open do |tmp|
      tmp.write(text)
      tmp.flush
      run_vim('--remote-send', "<ESC>:r #{tmp.path}<CR>")
    end
  end

  # Queries the Vim server for the current cursor column position.
  #
  # @return [Result] the command result; `stdout` contains the column
  #   number as a string (empty or "0" when the server is unreachable)
  def col
    run_vim('--remote-expr', "col('.')", stdout: true)
  end

  # Checks if a Vim server is currently running and accessible.
  #
  # @return [Boolean] true if the Vim server is running and accessible
  def server_running?
    result = col
    result.status.success? && result.stdout.to_i > 0
  end

  # Opens a file in Vim at a specified line and optionally marks a range.
  #
  # @param file_path [String] the path to the file to be opened in Vim
  # @param start_line [Integer] the line number to start at (defaults to 1)
  # @param end_line [Integer, nil] the line number to end at, if marking a
  #   range
  #
  # @return [Result] the last command result
  # @raise [OllamaChat::VimError] if the Vim server is not running
  def open_file(file_path, start_line = nil, end_line = nil)
    start_line ||= 1
    server_running? or raise OllamaChat::VimError,
      "Vim server #{@server_name.inspect} is not running"
    result = run_vim('--remote', "+#{start_line}", file_path)
    return result unless result.status.success?
    if end_line
      mark_range = "<ESC>:normal #{start_line}GV#{end_line}G<CR>"
      run_vim('--remote-send', mark_range)
    else
      run_vim('--remote-send', '<ESC>zz')
    end
  end

  private

  # Executes a vim client command via Open3.capture3, returning a Result.
  #
  # @param args [Array<String>] arguments appended after clientserver/
  #   servername
  # @param stdout [Boolean] capture stdout (only needed by #col)
  # @return [Result] the command result with status, stderr, and optional
  #   stdout
  def run_vim(*args, stdout: false)
    out, err, status = Open3.capture3(
      'vim', '--clientserver', clientserver,
      '--servername', server_name, *args
    )
    Result.new(status:, stderr: err, stdout: stdout ? out : nil)
  end
end
