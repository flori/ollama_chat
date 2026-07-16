# A tool for deleting files with an automatic backup.
#
# This tool allows the chat client to remove files from the local filesystem.
# To prevent accidental data loss, it creates a timestamped backup of the file
# in the XDG state home before deletion.
class OllamaChat::Tools::DeleteFile
  include OllamaChat::Tools::Concern
  include OllamaChat::Utils::PathValidator

  # @return [String] the registered name for this tool
  def self.register_name = 'delete_file'

  # The tool method creates and returns a tool definition for deleting files.
  #
  # @return [Ollama::Tool] a tool definition for deleting files with backup
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name: self.class.register_name,
        description: <<~EOT,
          File deleter – Deletes a file at the given path.
          A backup is automatically created before deletion. Path must be
          allowed.
        EOT
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            path: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The path to the file to delete (must be within allowed directories)'
            ),
          },
          required: %w[path]
        )
      )
    )
  end

  # The execute method processes a tool call to delete a file.
  #
  # It validates the path, performs a backup, and then removes the file.
  #
  # @param tool_call [Ollama::Tool::Call] the tool call containing function
  #   details
  # @param opts [Hash] additional options
  # @option opts [ComplexConfig::Settings] :chat the chat instance
  #
  # @return [String] the result of the file deletion operation as a JSON string
  # @return [String] a JSON string containing error information if the
  #   operation fails
  def execute(tool_call, **opts)
    chat   = opts[:chat]
    config = chat.config
    args   = tool_call.function.arguments

    path = assert_valid_path(args.path, config.tools.functions.delete_file.allowed?, check: :file)

    backup_path = perform_backup(path)

    path.delete

    {
      success: true,
      path:    path.to_s,
      backup:  backup_path.to_s,
      message: "File #{path} deleted successfully. Backup created at #{backup_path}.",
    }.to_json
  rescue => e
    chat.log(:error, e)
    {
      error:   e.class,
      path:    e.ask_and_send(:path),
      message: "Failed to delete file, #{e.class}: #{e.message}"
    }.to_json
  end

  self
end.register
