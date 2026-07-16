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
          appending based on mode.
          A backup is automatically created before writing, if the file already
          exists. Path must be allowed.
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
    chat   = opts[:chat]
    config = chat.config
    args   = tool_call.function.arguments

    path = assert_valid_path(args.path, config.tools.functions.write_file.allowed?)

    # Ensure the parent directory exists
    path.dirname.mkpath

    es = OllamaChat::TokenEstimator.estimate(args.content)

    backup_path = nil

    # Write the file
    case args.mode
    when 'append'
      File.open(path, 'a') do |f|
        backup_path = perform_backup(path)
        f.write(args.content)
      end
    when 'overwrite', nil
      File.secure_write(path) do |output|
        backup_path = perform_backup(path)
        output.write args.content
      end
    else
      raise ArgumentError, 'Invalid mode %s' % args.mode.inspect
    end

    message = "Wrote #{es.bytes_formatted} (#{es.tokens_formatted}) to file #{path.to_s.inspect}."

    {
      success: true,
      path:    path.to_s,
      backup:  backup_path.to_s,
      message: ,
    }.to_json
  rescue => e
    chat.log(:error, e)
    {
      error:   e.class,
      path:    e.ask_and_send(:path),
      message: "Failed to write to file: #{e.message}"
    }.to_json
  end

  self
end.register
