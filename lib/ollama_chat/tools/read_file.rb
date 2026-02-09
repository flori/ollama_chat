class OllamaChat::Tools::ReadFile
  include OllamaChat::Tools::Concern
  include OllamaChat::Utils::PathValidator

  def self.register_name = 'read_file'

  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name: 'read_file',
        description: 'Reads file content safely (path validated like write_file)',
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

  def execute(tool_call, **opts)
    config = opts[:config]
    args   = tool_call.function.arguments

    target_path = assert_valid_path(args.path, config.tools.read_file.allowed?)

    File.read(target_path)
  rescue => e
    {
      error:   e.class,
      path:    e.ask_and_send(:path),
      message: "Failed to read file: #{e.message}"
    }.to_json
  end

  self
end.register
