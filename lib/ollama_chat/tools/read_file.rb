# A tool for reading file content safely.
#
# This tool allows the chat client to read the contents of a file on the local
# filesystem. It integrates with the Ollama tool calling system to provide
# file reading capabilities to the language model.
#
# The tool validates the file path against allowed directories and returns
# the file contents as JSON.
class OllamaChat::Tools::ReadFile
  include OllamaChat::Tools::Concern
  include OllamaChat::Utils::PathValidator

  # @return [String] the registered name for this tool
  def self.register_name = 'read_file'

  # Creates and returns a tool definition for reading file content.
  #
  # This method constructs the function signature that describes what the tool
  # does, its parameters, and required fields. The tool expects a path
  # parameter for the file to be read.
  #
  # @return [Ollama::Tool] a tool definition for reading file content
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name: 'read_file',
        description: <<~EOT,
          File reader – Returns raw text from path if it’s within allowed
          directories. No side effects; useful for inspecting config or source
          files.
        EOT
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            path: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The path to the file to read (must be within allowed directories)'
            )
          },
          required: %w[path]
        )
      )
    )
  end

  # Executes the file reading operation.
  #
  # This method reads the content of the specified file after validating the
  # path against allowed directories. It returns the file contents as a JSON
  # string.
  #
  # @param tool_call [OllamaChat::Tool::Call] the tool call object containing function details
  # @param opts [Hash] additional options
  # @option opts [ComplexConfig::Settings] :config the configuration object
  #
  # @return [String] the file content as a JSON string containing `path` and `content` keys
  # @return [String] an error message as a JSON string if the operation fails
  # @raise [JSON::ParserError] if the result cannot be serialized to JSON
  def execute(tool_call, **opts)
    config = opts[:config]
    args   = tool_call.function.arguments

    path = assert_valid_path(args.path, config.tools.functions.read_file.allowed?)

    {
      path:,
      content: File.read(path),
    }.to_json
  rescue => e
    {
      error:   e.class,
      path:    e.ask_and_send(:path),
      message: "Failed to read file: #{e.message}"
    }.to_json
  end

  self
end.register
