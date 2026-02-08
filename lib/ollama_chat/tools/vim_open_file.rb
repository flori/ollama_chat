class OllamaChat::Tools::VimOpenFile
  include OllamaChat::Tools::Concern

  def self.register_name = 'vim_open_file'

  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: 'Open a file in the remote Vim server at a specific line or range',
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

  def execute(tool_call, **opts)
    chat       = opts[:chat]
    args       = tool_call.function.arguments
    file_path  = args.path
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
