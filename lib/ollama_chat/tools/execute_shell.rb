require 'open3'

# Shell command executor with mandatory human review.
#
# The LLM proposes a command; the user reviews it in their configured
# editor (modify or cancel), then answers a y/n/i confirm prompt that
# cannot be disabled via configuration.  Output is displayed via pager.
class OllamaChat::Tools::ExecuteShell
  include OllamaChat::Tools::Concern
  include Term::ANSIColor
  include OllamaChat::Utils::StripANSI

  # @return [String] the registered name for this tool
  def self.register_name = 'execute_shell'

  # Compaction summary: one-liner for lookup_group output.
  #
  # @param result [String] the raw JSON result string
  # @return [String] a short human-readable summary
  def self.summary_template(result:)
    data = JSON.parse(result)
    if data['error']
      "❌ #{data['message']}"
    else
      "✅ #{data['command']} (exit #{data['exit_code']})"
    end
  end

  # @return [Ollama::Tool] a tool definition for shell execution
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: <<~EOT,
          Shell executor – Runs a shell command via `sh -c`. The
          command is opened in your editor for review/modification,
          then a mandatory y/n/i confirm prompt gates execution.
          Last resort: use ONLY when no dedicated tool covers
          the task (e.g. `git commit`, `bundle install`, `make`).
          Prefer `execute_grep`, `directory_structure`, `read_file`,
          `patch_file` over shell equivalents. Only invoke when
          the user explicitly requests it or you have proposed
          the command to the user beforehand. Runs in the current
          working directory.
        EOT
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            command: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The shell command to execute'
            ),
            monochrome: Tool::Function::Parameters::Property.new(
              type: 'boolean',
              description: 'Strip ANSI codes from captured output' \
                           ' (default: true)'
            ),
          },
          required: %w[command]
        )
      )
    )
  end

  # Execute the shell command after editor review and confirmation.
  #
  # @param tool_call [OllamaChat::Tool::Call] the tool call with args
  # @param opts [Hash] additional options
  # @option opts [OllamaChat::Chat] :chat the chat instance
  # @return [String] a JSON result string
  def execute(tool_call, **opts)
    chat    = opts[:chat]
    args    = tool_call.function.arguments
    command = args.command.to_s.strip
    raise OllamaChat::ToolFunctionArgumentError,
          'command required' if command.empty?

    monochrome = args.monochrome.nil? ? true : args.monochrome

    unless OllamaChat.test_mode?
      reviewed = review(command, chat:)
      raise OllamaChat::ToolFunctionArgumentError,
            "Shell command cancelled by user: #{command}" unless reviewed
      command = reviewed

      STDOUT.puts "\n$ #{command}\n"
      answer = chat.confirm?(
        prompt: '❓ Allow ✅[y]es / ⛔️[n]o / 📝[i]nstruct? '
      )&.to_s&.downcase

      case answer
      when 'y'
        # proceed to execution
      when 'n'
        raise OllamaChat::ToolFunctionArgumentError,
              "Shell command cancelled by user: #{command}"
      else
        instr   = chat.ask?(prompt: '📝 Instructions: ')&.strip
        resolve = instr.full? || 'You **MUST** ask the user for instructions!'
        raise OllamaChat::ToolFunctionArgumentError,
              "User instruct: #{resolve} (command: #{command})"
      end
    end

    stdout, stderr, status = Open3.capture3('sh', '-c', command)
    exit_code = status.exitstatus
    if monochrome
      stdout = strip_ansi(stdout)
      stderr = strip_ansi(stderr)
    end

    chat.log(:info, 'Shell executed', data: {
      tool: name, command:, exit_code:,
      stdout_bytes: stdout.bytesize,
      stderr_bytes: stderr.bytesize,
    })

    display(chat, stdout, stderr, exit_code)

    {
      stdout:, stderr:, exit_code:, command:,
      message: "Shell command finished (exit #{exit_code}): #{command}",
    }.to_json
  rescue => e
    cmd = args&.command&.to_s
    chat.log(:error, e, data: { tool: name, command: cmd })
    { error: e.class.name, message: e.message, command: cmd }.to_json
  end

  private

  # Open the command in the user's editor for review.
  #
  # @return [String, nil] the (possibly modified) command, or nil
  #   if the user abandoned or cleared the editor.
  def review(command, chat:)
    edited = chat.edit_text(command, basename: %w[cmd .sh])
    edited.full?(:chomp)
  end

  # Display command output through the pager.
  def display(chat, stdout, stderr, exit_code)
    chat.use_pager do |io|
      if stdout.present?
        io.puts bold { "stdout:" }, ""
        io.puts stdout
      end
      if stderr.present?
        io.puts bold { "stderr:" }, ""
        io.puts stderr
      end
      io.puts bold{ "🎌 exit: #{exit_code}" }
    end
  end

  self
end.register
