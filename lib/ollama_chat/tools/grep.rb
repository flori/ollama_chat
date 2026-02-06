# A tool for searching files using grep command.
#
# This tool allows the chat client to execute grep commands to search for
# patterns in files. It integrates with the Ollama tool calling system to
# provide file search capabilities within the language model's context.
class OllamaChat::Tools::Grep
  include Ollama

  # Initializes a new Grep tool instance
  def initialize
    @name = 'execute_grep'
  end

  # Returns the tool definition for use with the Ollama API
  #
  # This method returns a tool definition that describes the grep tool's
  # capabilities, parameters, and usage for the LLM.
  #
  # @return [OllamaChat::Tool] The tool definition
  attr_reader :name

  # Returns the tool definition for use with the Ollama API
  #
  # This method returns a tool definition that describes the grep tool's
  # capabilities, parameters, and usage for the LLM.
  #
  # @return [OllamaChat::Tool] The tool definition
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: 'Search for a pattern in files using grep',
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            pattern: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The regex pattern to search for'
            ),
            path: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'Directory or file to search (defaults to current directory)'
            ),
            max_results: Tool::Function::Parameters::Property.new(
              type: 'integer',
              description: 'Maximum number of matches to return (optional)'
            )
          },
          required: %w[pattern]
        )
      )
    )
  end

  # Executes the grep command with the provided arguments
  #
  # This method runs the grep command with the specified pattern, path, and
  # maximum results limit. It uses Shellwords.escape for security and
  # OllamaChat::Utils::Fetcher to execute the command.
  #
  # @example
  #   result = grep_tool.execute(tool_call, config: config)
  #
  # @param tool_call [OllamaChat::Tool::Call] The tool call with arguments
  # @param opts [Hash] Additional options
  # @option opts [Hash] :config Configuration options including tool settings
  # @return [Hash] The execution result with command and output
  # @raise [StandardError] If the command execution fails
  def execute(tool_call, **opts)
    config      = opts[:config]
    args        = tool_call.function.arguments
    pattern     = Shellwords.escape(args.pattern)
    path        = Shellwords.escape(Pathname.new(args.path || '.').expand_path)
    max_results = args.max_results || 100
    cmd         = config.tools.execute_grep.cmd % { max_results:, path:, pattern: }
    result      = OllamaChat::Utils::Fetcher.execute(cmd, &:read)
    { cmd:, result: }.to_json
  rescue StandardError => e
    { error: e.class, message: e.message }.to_json
  end

  # Converts the tool to a hash representation
  #
  # This method returns the tool definition as a hash, which is useful for
  # serialization or when working with APIs that expect hash representations.
  #
  # @example
  #   tool_hash = grep_tool.to_hash
  #
  # @return [Hash] The tool definition as a hash
  def to_hash
    tool.to_hash
  end
end
