# A tool for searching files using grep command.
#
# This tool allows the chat client to execute grep commands to search for
# patterns in files. It integrates with the Ollama tool calling system to
# provide file search capabilities within the language model's context.
class OllamaChat::Tools::ExecuteGrep
  include OllamaChat::Tools::Concern

  def self.register_name = 'execute_grep'

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
            ),
            ignore_case: Tool::Function::Parameters::Property.new(
              type: 'boolean',
              description: 'Matches ignore case if true, (default: false)'
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
  #   result = grep_tool.execute(tool_call, config:, chat:)
  #
  # @param tool_call [OllamaChat::Tool::Call] The tool call with arguments
  # @param opts [Hash] Additional options
  # @option opts [Hash] :config Configuration options including tool settings
  # @return [String] The execution result with command and output as JSON string
  def execute(tool_call, **opts)
    config      = opts[:config]
    args        = tool_call.function.arguments
    pattern     = Shellwords.escape(args.pattern)
    path        = Shellwords.escape(Pathname.new(args.path || '.').expand_path)
    max_results = args.max_results || 100
    ignore_case = args.ignore_case || false
    cmd         = eval_template(config, pattern, path, max_results, ignore_case)
    result      = OllamaChat::Utils::Fetcher.execute(cmd, &:read)
    { cmd:, result: }.to_json
  rescue => e
    { error: e.class, message: e.message }.to_json
  end

  private

  # Evaluates a template string using the provided configuration and
  # parameters.
  #
  # @param config [Object] the configuration object containing tool settings
  # @param pattern [String] the regex pattern to search for
  # @param path [String] the file or directory path to search in
  # @param max_results [Integer] the maximum number of matches to return
  # @param ignore_case [Boolean] whether to ignore case when searching
  #
  # @return [String] the evaluated template string with substituted variables
  def eval_template(config, pattern, path, max_results, ignore_case)
    eval('"%s"' % config.tools.execute_grep.cmd.chomp)
  end

  self
end.register
