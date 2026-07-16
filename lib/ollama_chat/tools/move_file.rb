# A tool for moving or renaming files.
#
# This tool allows the chat client to move a file from a source path to a
# destination path. The destination path must not already exist.
class OllamaChat::Tools::MoveFile
  include OllamaChat::Tools::Concern
  include OllamaChat::Utils::PathValidator

  # @return [String] the registered name for this tool
  def self.register_name = 'move_file'

  # The tool method creates and returns a tool definition for moving files.
  #
  # @return [Ollama::Tool] a tool definition for moving files
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name: self.class.register_name,
        description: <<~EOT,
          File mover/renamer – Moves a file from the source path to the destination path.
          The destination path must not already exist. Both paths must be allowed.
        EOT
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            source: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The path to the file to move (must be within allowed directories)'
            ),
            destination: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The destination path (must be within allowed directories and must not exist)'
            ),
          },
          required: %w[source destination]
        )
      )
    )
  end

  # The execute method processes a tool call to move a file.
  #
  # It validates both paths (ensuring the source exists and the destination does not),
  # and then moves the file.
  #
  # @param tool_call [Ollama::Tool::Call] the tool call containing function
  #   details
  # @param opts [Hash] additional options
  # @option opts [ComplexConfig::Settings] :chat the chat instance
  #
  # @return [String] the result of the move operation as a JSON string
  # @return [String] a JSON string containing error information if the
  #   operation fails
  def execute(tool_call, **opts)
    chat   = opts[:chat]
    config = chat.config
    args   = tool_call.function.arguments

    # Validate paths
    # source: must exist and be a file
    # destination: must NOT exist (check: false)
    source      = assert_valid_path(args.source, config.tools.functions.move_file.allowed?, check: :file)
    destination = assert_valid_path(args.destination, config.tools.functions.move_file.allowed?, check: false)

    # Ensure destination parent directory exists
    destination.dirname.mkpath

    # Perform the move
    FileUtils.mv(source, destination)

    {
      success:     true,
      source:      source.to_s,
      destination: destination.to_s,
      message:     "File moved successfully from #{source} to #{destination}.",
    }.to_json
  rescue => e
    chat.log(:error, e)
    {
      error:   e.class,
      source:  e.ask_and_send(:source),
      dest:    e.ask_and_send(:destination),
      message: "Failed to move file, #{e.class}: #{e.message}"
    }.to_json
  end

  self
end.register
