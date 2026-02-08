# A tool for writing content to files with overwrite or append modes.
#
# This tool enables the chat client to write text content to files on the local
# filesystem. It supports both overwriting existing files and appending content
# to them, with configurable file permissions and safety checks to prevent
# writing to unauthorized locations.
class OllamaChat::Tools::FileWriter
  include OllamaChat::Tools::Concern

  def self.register_name = 'write_file'

  # The tool method creates and returns a tool definition for writing content
  # to files.
  #
  # @return [Ollama::Tool] a tool definition for writing content to files with
  # overwrite/append modes
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: 'Write content to a file with modes overwrite/append, (default: overwrite)',
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            path: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The path to the file to write (must be within allowed directories)'
            ),
            content: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The content to write to the file'
            ),
            mode: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The file mode (append or overwrite, default: overwrite)',
              enum: %w[overwrite append]
            )
          },
          required: %w[path content]
        )
      )
    )
  end

  # The execute method processes a tool call to write content to a file.
  #
  # This method handles writing text content to files on the local filesystem,
  # supporting both overwriting and appending modes. It validates that the
  # target path is within allowed directories and ensures the parent directory
  # exists before writing.
  #
  # @param tool_call [Ollama::Tool::Call] the tool call containing function
  #   details
  # @param opts [Hash] additional options
  # @option opts [ComplexConfig::Settings] :config the configuration object
  #
  # @return [String] the result of the file write operation as a JSON string
  # @return [String] a JSON string containing error information if the
  #   operation fails
  def execute(tool_call, **opts)
    config = opts[:config]
    args = tool_call.function.arguments

    # Get allowed directories from configuration
    allowed_dirs = Array(config.tools.write_file.allowed?).map {
      Pathname.new(_1).expand_path
    }
    path = Pathname.new(args.path).expand_path

    # Validate that the path is within allowed directories
    unless valid_path?(path, allowed_dirs)
      raise ArgumentError, "Path #{args.path.inspect} is not within allowed "\
        "directories: #{allowed_dirs&.join(', ') || ?∅}"
    end

    # Resolve the full path
    target_path = Pathname.pwd.join(path).cleanpath

    # Ensure the parent directory exists
    target_path.parent.mkpath

    # Write the file
    if args.mode == 'append'
      File.open(target_path, 'a') { |f| f.write(args.content) }
    else
      File.secure_write(target_path, args.content)
    end

    {
      success: true,
      path: target_path.to_s
    }.to_json
  rescue => e
    {
      error: e.class,
      message: "Failed to write to file: #{e.message}"
    }.to_json
  end

  private

  # The valid_path? method checks if a given path is within any of the allowed
  # directories.
  #
  # This method takes a path and a set of allowed directories, converts both to
  # absolute paths, and determines whether the given path is located within any
  # of the allowed directories.
  #
  # @param path [Pathname] the path to check
  # @param allowed_dirs [Array<Pathname>] an array of allowed directory paths
  #
  # @return [TrueClass, FalseClass] true if the path is within any allowed
  #   directory, false otherwise
  def valid_path?(path, allowed_dirs)
    # Convert to absolute paths for comparison
    absolute_path = Pathname.pwd.join(path).cleanpath

    # Check if path is within any allowed directory
    allowed_dirs.any? do |allowed_path|
      absolute_path.to_s.start_with?(allowed_path.to_s)
    end
  end

  self
end.register
