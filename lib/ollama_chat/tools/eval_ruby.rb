require 'open3'

# A tool for evaluating Ruby code in a sandboxed Docker environment.
#
# This tool allows the chat client to execute Ruby source code by piping it
# into a Docker container running the specified Ruby alpine image.
# It provides a safe way to test snippets and verify Ruby behavior.
class OllamaChat::Tools::EvalRuby
  include OllamaChat::Tools::Concern

  # @return [String] the registered name for this tool
  def self.register_name = 'eval_ruby'

  # Creates and returns a tool definition for evaluating Ruby code.
  #
  # @return [Ollama::Tool] a tool definition for the Ruby evaluator
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name: 'eval_ruby',
        description: <<~EOT,
          Evaluates Ruby code in a sandboxed Docker container (ruby:#{RUBY_VERSION}-alpine).
          Pipes the source text to IRB with a minimal prompt.
          Useful for verifying syntax, testing logic, or exploring Ruby behavior.
        EOT
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            source: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The Ruby source code to evaluate'
            ),
            version: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: "The Ruby version this will be evaluated in (default: #{RUBY_VERSION})"
            )
          },
          required: %w[source]
        )
      )
    )
  end

  # Executes the Ruby code via Docker.
  #
  # @param tool_call [OllamaChat::Tool::Call] the tool call object containing function details
  # @param opts [Hash] additional options
  #
  # @return [String] a JSON string containing the `result` (stdout) or an `error`
  def execute(tool_call, **_opts)
    args = tool_call.function.arguments
    source = args.source.full? or
      raise OllamaChat::ToolFunctionArgumentError, 'require source to evaluate'
    version = args.version.full? || RUBY_VERSION

    # Command similar to `docker run -i ruby:4.0.5-alpine irb --prompt xmp`
    # We pipe the source text directly into the container's stdin.
    cmd = [
      'docker', 'run',
      '--user', 'nobody:nobody',
      '--network', 'none',
      '--cap-drop', 'all',
      '--security-opt', 'no-new-privileges',
      '--rm',
      '-i',
      OC::OLLAMA::CHAT::TOOLS::RUBY_EVAL_IMAGE_TEMPLATE % { version: },
      'irb',
      '--prompt',
      'simple'
    ]

    stdout, stderr, status = Open3.capture3(*cmd, stdin_data: source)

    result = stdout&.sub(/\ASwitch to inspect mode.\n/, '')

    if status.success?
      {
        result:,
        version:,
        status: 'success'
      }.to_json
    else
      {
        error: 'ExecutionError',
        message: stderr.empty? ? "Process exited with status #{status.exitstatus}" : stderr,
        version:,
        stdout:,
        exit_status: status.exitstatus
      }.to_json
    end
  rescue => e
    {
      error: e.class,
      message: "Failed to evaluate Ruby code: #{e.message}"
    }.to_json
  end

  self
end.register
