# A tool for opening files in a the Vim Editor.
#
# This tool allows the chat client to open files in vim at specific line
# numbers or line ranges. It integrates with the Ollama tool calling
# system to provide file editing capabilities.
class OllamaChat::Tools::OpenFileInEditor
  include OllamaChat::Tools::Concern

  def self.register_name = 'open_file_in_editor'

  # The tool method defines the Ollama tool specification for Vim file opening.
  #
  # This method creates a Tool object that describes the Vim open file
  # functionality to the Ollama system. It specifies the tool's name,
  # description, and parameters that can be used when calling the tool.
  #
  # @return [Ollama::Tool] the tool specification object
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: 'Open a file in the vim editor at a specific line or range',
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            path: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The file path to open in Vim'
            ),
            start_line: Tool::Function::Parameters::Property.new(
              type: 'integer',
              description: 'Line number to navigate to (or start of range)'
            ),
            end_line: Tool::Function::Parameters::Property.new(
              type: 'integer',
              description: 'End line number of range (optional)'
            )
          },
          required: %w[path start_line]
        )
      )
    )
  end

  # The execute method processes a tool call to open a file in Vim.
  #
  # This method handles the actual execution of opening a file in the Vim  at
  # the specified line or line range. It validates that the file exists and
  # then calls the chat's vim.open_file method.
  #
  # @param tool_call [Ollama::Tool::Call] the tool call containing function details
  # @param opts [Hash] additional options
  # @option opts [OllamaChat::Chat] :chat the chat instance
  #
  # @return [String] a JSON string containing the result of the operation
  # @return [String] a JSON string containing error information if the operation fails
  def execute(tool_call, **opts)
    chat       = opts[:chat]
    args       = tool_call.function.arguments
    file_path  = Pathname.new(args.path).expand_path
    start_line = args.start_line
    end_line   = args.end_line

    # Validate file exists
    unless File.exist?(file_path)
      raise Errno::ENOENT, "could not find file: #{file_path}"
    end

    chat.vim.open_file(file_path, start_line, end_line)
    if end_line
      result_msg = "Opened #{file_path} and selected range #{start_line}-#{end_line}"
    else
      result_msg = "Opened #{file_path} at line #{start_line}"
    end

    {
      success: true,
      message: result_msg,
      path: file_path,
      start_line: start_line,
      end_line: end_line,
    }.to_json

  rescue => e
    {
      error: e.class,
      message: e.message
    }.to_json
  end

  self
end.register
