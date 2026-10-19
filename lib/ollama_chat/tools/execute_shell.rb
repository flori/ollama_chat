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

  # In-memory set of always-allowed command strings (per process).
  #
  # @return [Hash{String => true}]
  def self.always_allowed
    @always_allowed ||= {}
  end

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
          then a mandatory y/n/i/a confirm prompt gates execution.
          Answering a remembers the command for the session
          (skips editor and confirm on repeat).
          Last resort: use ONLY when no dedicated tool covers
          the task (e.g. `git commit`, `bundle install`, `make`).
          Prefer `execute_grep`, `list_directory`, `read_file`,
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
  # @return [String] a JSON result string
  def execute(tool_call, **opts)
    args    = tool_call.function.arguments
    command = args.command.to_s.strip
    raise OllamaChat::ToolFunctionArgumentError,
          'command required' if command.empty?

    monochrome = args.monochrome.nil? ? true : args.monochrome

    unless OllamaChat.test_mode?
      mode = self.class.always_allowed[command]
      if mode
        label = mode == :direct ? '📄 Direct' : '☑️ Always allowed'
        feedback "#{label} (this process)\n$ #{command}\n"
      else
        reviewed = review(command)
        raise OllamaChat::ToolFunctionArgumentError,
          "Shell command cancelled by user: #{command}" unless reviewed
        command = reviewed

        feedback(<<~EOT)
          $ #{command}

          y once · n cancel · i instruct me · a always (pager) · d always (direct)

        EOT
        answer = chat.confirm?(
          prompt: '❓ Allow ✅[y]es / ⛔️[n]o / 📝[i]nstruct / 🔁[a]lways / 📄[d]irect? '
        )&.to_s&.downcase

        case answer
        when 'y'
          # proceed to execution
        when 'a'
          self.class.always_allowed[command] = :always
        when 'd'
          self.class.always_allowed[command] = :direct
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

    display(stdout, stderr, exit_code, direct: mode == :direct)

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
  def review(command)
    edited = chat.edit_text(command, basename: %w[cmd .sh])
    edited.full?(:chomp)
  end

  # Display command output through the pager or directly to STDOUT.
  def display(stdout, stderr, exit_code, direct: false)
    if direct
      write_output(STDOUT, stdout, stderr, exit_code)
    else
      chat.use_pager(force: true) do |io|
        write_output(io, stdout, stderr, exit_code)
      end
    end
  end

  # Writes the output of a command or process to an IO object,
  # formatting the stdout and stderr sections with bold headers,
  # followed by a bold line indicating the exit code.
  #
  # @param io [ IO ] the IO object to write to
  # @param stdout [ String ] the standard output content to display
  # @param stderr [ String ] the standard error content to display
  # @param exit_code [ Integer ] the exit code of the process
  def write_output(io, stdout, stderr, exit_code)
    if stdout.present?
      io.puts bold { "stdout:" }, ""
      io.puts stdout
    end
    if stderr.present?
      io.puts bold { "stderr:" }, ""
      io.puts stderr
    end
    io.puts bold { "🎌 exit: #{exit_code}" }
  end

  self
end.register
