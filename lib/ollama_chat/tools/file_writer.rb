class OllamaChat::Tools::FileWriter
  include OllamaChat::Tools::Concern

  def self.register_name = 'write_file'

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
