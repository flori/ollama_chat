# A tool for writing content to files with overwrite or append modes.
#
# This tool enables the chat client to write text content to files on the local
# filesystem. It supports both overwriting existing files and appending content
# to them, with configurable file permissions and safety checks to prevent
# writing to unauthorized locations.
class OllamaChat::Tools::WriteFile
  include OllamaChat::Tools::Concern
  include OllamaChat::Utils::PathValidator

  # @return [String] the registered name for this tool
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
        description: <<~EOT,
          File writer – Saves content into path, either overwriting or
          appending based on mode. Path must be allowed; no return value.
        EOT
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
  # @option opts [ComplexConfig::Settings] :chat the chat instance
  #
  # @return [String] the result of the file write operation as a JSON string
  # @return [String] a JSON string containing error information if the
  #   operation fails
  def execute(tool_call, **opts)
    config = opts[:chat].config
    args   = tool_call.function.arguments

    target_path = assert_valid_path(args.path, config.tools.functions.write_file.allowed?)

    # Ensure the parent directory exists
    target_path.parent.mkpath

    bytes_written = args.content&.size.to_i

    # Write the file
    case args.mode
    when 'append'
      File.open(target_path, 'a') { |f| f.write(args.content) }
    when 'overwrite', nil
      File.secure_write(target_path, args.content)
    else
      raise ArgumentError, 'Invalid mode %s' % args.mode.inspect
    end

    {
      success:         true,
      path:            target_path.to_s,
      bytes_written:   ,
    }.to_json
  rescue => e
    {
      error:   e.class,
      path:    e.ask_and_send(:path),
      message: "Failed to write to file: #{e.message}"
    }.to_json
  end

  self
end.register
