# Tool for executing RSpec / Test‑Unit test suites.
#
# The tool is registered under the name ``run_tests`` and exposes a single
# function that accepts a ``path`` (file or directory) and an optional
# ``coverage`` flag.  The implementation simply spawns the configured test
# runner (RSpec or Minitest) and streams its output back to the caller.
class OllamaChat::Tools::RunTests
  include OllamaChat::Tools::Concern
  include OllamaChat::Utils::PathValidator

  # @return [String] the registered name for this tool
  def self.register_name = 'run_tests'

  # Build the OpenAI function schema for the tool.
  # @return [Tool]
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name: 'run_tests',
        description: <<~EOT,
           Test Runner - Runs all tests/specs under *path* the path were the
           tests/specs are located. `coverage=false` by default; set to true
           for a coverage report. Returns JSON with test counts and, if
           requested, coverage percentage.
        EOT
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            path: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'Path to file or directory to run tests for (path has to be allowed!)'
            ),
            coverage: Tool::Function::Parameters::Property.new(
              type: 'boolean',
              description: 'True if coverage data should be created, (default: false)'
            )
          },
          required: []
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
    config   = opts[:chat].config
    path     = tool_call.function.arguments.path
    coverage = tool_call.function.arguments.coverage || false
    check_path(path, config)
    output, success = run_tests(path, coverage)
    {
      success:,
      path:,
      output:,
      status: success ? 'passed' : 'failed'
    }.to_json
  rescue => e
    { error: e.class, message: e.message }.to_json
  end

  private

  # The check_path method determines the appropriate test directory path based
  # on existing directories and validates it against a whitelist.
  #
  # @param path [ String ] the initial path to be checked
  # @param config [ Object ] configuration object containing tool function settings
  # @return [ String ] the validated and existing path
  def check_path(path, config)
    if path.blank?
      if File.exist?('./spec')
        path = './spec'
      elsif File.exist?('./test')
        path = './test'
      elsif File.exist?('./tests')
        path = './tests'
      else
        raise ArgumentError, 'path could not be determined'
      end
    end
    assert_valid_path(path, config.tools.functions.run_tests.allowed?)
    File.exist?(path) or raise Errno::ENOENT, 'path %s does not exist' % path.inspect
  end

  # Run the test suite using the configured test runner.
  #
  # @param path [String] file or directory to test
  # @param coverage [true, false] whether to enable SimpleCov
  # @return [Array(String, true, false)] the captured output and a success flag
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
    OC::OLLAMA::CHAT::TOOLS::TEST_RUNNER
  end

  self.register
end
