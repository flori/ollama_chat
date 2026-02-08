class OllamaChat::Tools::RunTests
  include OllamaChat::Tools::Concern

  def self.register_name = 'run_tests'

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

  def test_runner
    OllamaChat::EnvConfig::OLLAMA::CHAT::TOOLS::RUN_TESTS_TEST_RUNNER
  end

  self.register
end
