# A tool for executing TWG CLI commands.
#
# This tool allows the chat client to run `twg` subcommands for Atlassian
# Teamwork Graph operations — Jira workitems, Confluence, Rovo search,
# user lookups, and more. It integrates with the Ollama tool calling
# system to provide project-management and cross-product capabilities.
#
# The command string is parsed with Shellwords.shellsplit to safely
# handle quoted arguments (e.g. JQL, rich text) before execution.
class OllamaChat::Tools::ExecuteJIRATWG
  include OllamaChat::Tools::Concern

  # @return [String] the registered name for this tool
  def self.register_name = 'execute_jira_twg'

  # Returns the tool definition for use with the Ollama API.
  #
  # @return [OllamaChat::Tool] The tool definition
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: <<~EOT,
          TWG CLI executor – Runs a `twg` subcommand against the Atlassian
          Teamwork Graph. Command families: `jira workitem` (get, search,
          query, transition, comment, link), `confluence`, `user`, `work`,
          `rovo search`, `org-tree`, `goals`, `projects`, `assets`,
          `pull-requests`, `search-code`, `trello`, `context`.
          Use `help discover-skills "<intent>"` or `help describe
          "skill:<name>/<path>"` to discover syntax.
          Read-only commands are safe; mutations (transition, comment,
          create, update, link) change Jira/Confluence state.
        EOT
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            command: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The twg subcommand and arguments, ' \
                           'e.g. "jira workitem get DEV-29042" or ' \
                           'jira workitem query --jql \"project = DEV\"'
            ),
          },
          required: %w[command]
        )
      )
    )
  end

  # Executes the twg command with the provided arguments.
  #
  # @param tool_call [OllamaChat::Tool::Call] The tool call with arguments
  # @param opts [Hash] Additional options
  # @option opts [OllamaChat::Chat] :chat the chat instance
  # @return [String] The execution result as JSON string
  def execute(tool_call, **opts)
    chat    = opts[:chat]
    command = tool_call.function.arguments.command
    command.full? or raise OllamaChat::ToolFunctionArgumentError,
      'require a command for twg'
    twg_path = OC::OLLAMA::CHAT::TOOLS::JIRA::TWG? or
      raise OllamaChat::ConfigMissingError,
        'Require env var %s configuration for TWG CLI' %
          OC::OLLAMA::CHAT::TOOLS::JIRA::TWG!.env_var_name
    args   = Shellwords.shellsplit(command)
    cmd    = [twg_path] + args
    result = OllamaChat::Utils::Fetcher.execute(cmd, &:read)
    if status = $?.exitstatus.nonzero?
      raise OllamaChat::ExecuteError,
        "twg #{command} exited with code #{status}:\n#{result}"
    end
    chat.log(:info, 'TWG executed', data: { tool: name, command: })
    message = Kramdown::ANSI::Width.truncate(
      result.lines.map(&:strip).reject(&:empty?).first || '(empty)',
      percentage: 90
    )
    { cmd:, result:, message: }.to_json
  rescue => e
    chat.log(:error, e, data: { tool: name, command: })
    { error: e.class, message: e.message }.to_json
  end

  self
end.register
