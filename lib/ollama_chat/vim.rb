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

  # Snapshot of the current server/buffer state, queried in a single
  # round-trip.
  class State < Data.define(:modifiable, :line, :col, :file_path)
    # @!attribute modifiable
    #   @return [Integer] 1 if the buffer accepts changes, 0 otherwise
    # @!attribute line
    #   @return [Integer] current cursor line (1-indexed)
    # @!attribute col
    #   @return [Integer] current cursor column (1-indexed)
    # @!attribute file_path
    #   @return [String] full path of the current buffer (empty for
    #     non-file buffers)

    # @return [Boolean] true if the buffer accepts changes
    def modifiable?
      modifiable > 0
    end

    # @return [Boolean] true if a cursor is present (col > 0)
    def cursor_present?
      col > 0
    end
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
    @server_name   = server_name
    @clientserver  = clientserver || 'socket'
    @current_state = nil
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
  # @raise [OllamaChat::VimError] if the server is not running or the
  #   current buffer is not modifiable
  def insert(text)
    info = current_state or raise OllamaChat::VimError,
      "Vim server #{server_name.inspect} is not running"
    info.modifiable? or raise OllamaChat::VimError,
      'Current buffer is not modifiable'
    spaces = (info.col - 1).clamp(0..)
    text   = text.gsub(/^/, ' ' * spaces)
    Tempfile.open do |tmp|
      tmp.write(text)
      tmp.flush
      run_vim('--remote-send', "<ESC>:r #{tmp.path}<CR>")
    end
  end

  # Returns the current cursor column position in Vim.
  #
  # @return [Integer, nil] the column number (1-indexed), or nil when the
  #   server is unreachable
  def column
    current_state&.col
  end

  # Returns the current cursor line position in Vim.
  #
  # @return [Integer, nil] the line number (1-indexed), or nil when the
  #   server is unreachable
  def line
    current_state&.line
  end

  # Returns the current buffer's file path as an absolute path.
  #
  # @return [String, nil] the full path, empty string for non-file
  #   buffers, or nil when the server is unreachable
  def file_path
    current_state&.file_path
  end

  # Checks if a Vim server is currently running and accessible.
  #
  # @return [Boolean] true if the Vim server is running and accessible
  def server_running?
    current_state&.cursor_present? || false
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
    file_pathname = Pathname.new(file_path)
    start_line ||= 1
    server_running? or raise OllamaChat::VimError,
      "Vim server #{@server_name.inspect} is not running"
    result = run_vim('--remote', "+#{start_line}", file_pathname.to_path)
    return result unless result.status.success?
    if end_line
      mark_range = "<ESC>:normal #{start_line}GV#{end_line}G<CR>"
      run_vim('--remote-send', mark_range)
    else
      run_vim('--remote-send', '<ESC>zz')
    end
  end

  # Discards the cached buffer state, forcing the next read to query
  # the Vim server.
  #
  # Call this after any operation that mutates the buffer or cursor
  # position (e.g. `insert`, `open_file`) so subsequent reads of
  # `line`, `column`, `file_path`, or `server_running?` reflect the
  # new state.
  def flush_state
    @current_state = nil
  end

  private

  # Queries the Vim server for buffer state in a single round-trip.
  #
  # Evaluates `json_encode([&modifiable, line('.'), col('.'),
  # expand('%:p')])` via `--remote-expr`, returning all values as a JSON
  # array in one call. When the server is unreachable, stdout is empty
  # (exit 0) and no JSON is found.
  #
  # The result is cached on the instance; subsequent calls return the
  # cached value without spawning a new process. Use {#flush_state} to
  # invalidate the cache after a buffer mutation.
  #
  # @return [State, nil] the buffer state, or nil when the server is
  #   unreachable
  def current_state
    @current_state and return @current_state
    result = run_vim(
      '--remote-expr',
      "json_encode([&modifiable, line('.'), col('.'), expand('%:p')])",
      stdout: true
    )
    json = result.stdout.strip
    return nil unless result.status.success? && json.present?
    modifiable, line, col, file_path = JSON.parse(json)
    @current_state = State.new(modifiable:, line:, col:, file_path:)
  end

  # Executes a vim client command via Open3.capture3, returning a Result.
  #
  # @param args [Array<String>] arguments appended after clientserver/
  #   servername
  # @param stdout [Boolean] capture stdout
  def run_vim(*args, stdout: false)
    out, err, status = Open3.capture3(
      'vim', '--clientserver', clientserver,
      '--servername', server_name, *args
    )
    Result.new(status:, stderr: err, stdout: stdout ? out : nil)
  end
end
