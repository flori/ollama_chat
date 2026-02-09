# Tool for executing RSpec / Test‑Unit test suites.
#
# The tool is registered under the name ``run_tests`` and exposes a single
# function that accepts a ``path`` (file or directory) and an optional
# ``coverage`` flag.  The implementation simply spawns the configured test
# runner (RSpec or Minitest) and streams its output back to the caller.
class OllamaChat::Tools::RunTests
  include OllamaChat::Tools::Concern

  # Register the tool name used by the OllamaChat runtime.
  # @return [String]
  def self.register_name = 'run_tests'

  # Build the OpenAI function schema for the tool.
  # @return [Tool]
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name: 'run_tests',
        description: 'Run RSpec / Test-Unit tests for a file or directory path',
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            path: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'Path to file or directory to run tests for (default: spec/)'
            ),
            coverage: Tool::Function::Parameters::Property.new(
              type: 'boolean',
              description: 'True if coverage data should be created, (default: false)'
            )
          },
          required: %w[ path ]
        )
      )
    )
  end

  # Execute the tool with the provided arguments.
  #
  # @param tool_call [ToolCall] the tool invocation containing arguments
  # @param opts [Hash] additional options (currently unused)
  # @return [String] JSON containing ``success``, ``path``, ``output`` and ``status``
  def execute(tool_call, **opts)
    path            = tool_call.function.arguments.path
    coverage        = tool_call.function.arguments.coverage || false
    output, success = run_tests(path, coverage)
    {
      success: success,
      path: path,
      output: output,
      status: success ? 'passed' : 'failed'
    }.to_json
  end

  private

  # Run the test suite using the configured test runner.
  #
  # @param path [String] file or directory to test
  # @param coverage [Boolean] whether to enable SimpleCov
  # @return [Array(String, Boolean)] the captured output and a success flag
  def run_tests(path, coverage)
    output = +''
    env = ENV.to_h | { 'START_SIMPLECOV' => coverage ? '1' : '0' }
    IO.popen(env, "#{test_runner} #{path} 2>&1", ?r) do |io|
      while line = io.gets
        STDOUT.puts line
        output << line
      end
    end
    return output, $?.success?
  end

  # Resolve the test runner executable from configuration.
  #
  # @return [String] the command to invoke the test runner
  def test_runner
    OllamaChat::EnvConfig::OLLAMA::CHAT::TOOLS::RUN_TESTS_TEST_RUNNER
  end

  self.register
end
