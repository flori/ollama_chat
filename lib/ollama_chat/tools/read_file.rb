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
  # does, its parameters, and required fields.
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
          files. You can optionally specify a line range to read.
        EOT
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            path: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The path to the file to read (must be within allowed directories)'
            ),
            start_line: Tool::Function::Parameters::Property.new(
              type: 'integer',
              description: 'The line number to start reading from (1-indexed)'
            ),
            end_line: Tool::Function::Parameters::Property.new(
              type: 'integer',
              description: 'The line number to stop reading at (1-indexed)'
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
  # @option opts [ComplexConfig::Settings] :chat the chat instance
  #
  # @return [String] the file content as a JSON string containing `path` and `content` keys
  # @return [String] an error message as a JSON string if the operation fails
  # @raise [JSON::ParserError] if the result cannot be serialized to JSON
  def execute(tool_call, **opts)
    config = opts[:chat].config
    args   = tool_call.function.arguments

    start_line = args.start_line.full?
    end_line   = args.end_line.full?

    path    = assert_valid_path(args.path, config.tools.functions.read_file.allowed?, check: :file)
    content = extract_range(path.read, start_line, end_line)
    es      = OllamaChat::TokenEstimator.estimate(content)
    message = "Read #{es.bytes_formatted} (#{es.tokens_formatted}) from #{path.to_s.inspect}."

    {
      path:,
      content:,
      start_line:,
      end_line:,
      message:,
    }.to_json
  rescue => e
    {
      error:   e.class,
      path:    e.ask_and_send(:path),
      message: "Failed to read file: #{e.message}",
      start_line:,
      end_line:,
    }.to_json
  end

  private

  # Extracts a specific range of lines from the provided string content.
  #
  # @param content [String] the source text to extract lines from.
  # @param start_line [Integer, nil] the 1-indexed starting line number.
  #   If nil, defaults to the first line.
  # @param end_line [Integer, nil] the 1-indexed ending line number.
  #   If nil, extracts until the end of the content.
  # @return [String] the extracted substring containing the requested line range.
  #   Returns an empty string if `end_line` is less than `start_line`.
  def extract_range(content, start_line, end_line)
    case
    when start_line.nil? && end_line.nil?
      content
    when start_line.nil?
      extract_range(content, 1, end_line)
    when end_line.nil?
      extract_range(content, start_line, Float::INFINITY)
    else
      new_content = +''
      end_line < start_line and return new_content
      content.each_line.each_with_index do |line, index|
        line_number = index + 1
        line_number < start_line and next
        new_content << line
        line_number >= end_line and break
      end
      new_content
    end
  end

  self
end.register
