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
          File writer - Saves content into path, either overwriting or
          appending based on `mode`. A backup is automatically created before
          writing, if the file already exists. Path must be allowed.
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

    # Confirm overwrite if file already exists
    if path.exist? && (args.mode == 'overwrite' || args.mode.nil?)
      unless chat.confirm?(prompt: "File #{path.to_s.inspect} already exists. Overwrite? (y/N): ", yes: /\Ay/i)
        raise OllamaChat::ToolFunctionArgumentError,
          "Write rejected: File #{path.to_s.inspect} already exists and was not overwritten."
      end
    end

    # Confirm creation if file doesn't exist in append mode
    if !path.exist? && args.mode == 'append'
      unless chat.confirm?(prompt: "File #{path.to_s.inspect} does not exist. Create it? (y/N): ", yes: /\Ay/i)
        raise OllamaChat::ToolFunctionArgumentError,
          "Write rejected: File #{path.to_s.inspect} does not exist and was not created."
      end
    end

    backup_path = nil

    content = args.content

    # Write the file
    case args.mode
    when 'append'
      File.open(path, 'a') do |f|
        backup_path = perform_backup(path)
        f.write(content)
      end
    when 'overwrite', nil
      File.secure_write(path) do |output|
        backup_path = perform_backup(path)
        output.write content
      end
    else
      raise ArgumentError, 'Invalid mode %s' % args.mode.inspect
    end

    syntax_check = nil
    if checker = chat.syntax_checker_for(path)
      check = chat.run_syntax_check(checker, path)
      syntax_check = check if check &&
        (check[:status] == 'fail' || check[:output] != '')
    end

    message = "Wrote #{es.bytes_formatted} (#{es.tokens_formatted}) to file #{path.to_s.inspect}."
    if syntax_check
      case syntax_check[:status]
      when 'fail'
        message << " — ❌ Syntax error detected"
      when 'pass'
        if warning = syntax_check[:output].lines.first&.chomp
          message << " — ⚠️ #{warning}"
        end
      end
    end

    chat.log(:info, "File written", data: {
      tool: name, path: path.to_s, mode: args.mode || 'overwrite', bytes: es.bytes_formatted
    })

    {
      success:      true,
      path:         path.to_s,
      backup:       backup_path.to_s,
      message:      ,
      syntax_check: syntax_check,
    }.compact.to_json
  rescue => e
    chat.log(:error, e, data: { tool: name, path: args.path })
    {
      error:   e.class,
      path:    e.ask_and_send(:path),
      message: "Failed to write to file: #{e.message}"
    }.to_json
  end

  self
end.register
