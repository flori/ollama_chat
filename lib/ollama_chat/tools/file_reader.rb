class OllamaChat::Tools::FileReader
  include OllamaChat::Tools::Concern

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

    # Get allowed directories from configuration
    allowed_dirs = Array(config.tools.read_file.allowed?).map {
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
    File.read(target_path)
  rescue => e
    {
      error:   e.class,
      path:,
      message: "Failed to read file: #{e.message}"
    }.to_json
  end

  private

  def valid_path?(path, allowed_dirs)
    absolute_path = Pathname.pwd.join(path).cleanpath
    allowed_dirs.any? { |allowed| absolute_path.to_s.start_with?(allowed.to_s) }
  end

  self
end.register
