describe OllamaChat::Tools::ExecuteShell do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  connect_to_ollama_server

  let :tool do
    described_class.new
  end

  before do
    allow(OllamaChat).to receive(:test_mode?).and_return(false)
    allow(chat).to receive(:log)
    allow(OC).to receive(:EDITOR?).and_return('vim')
  end

  def tool_call(command, monochrome: nil)
    double('ToolCall', function: double(
      name: 'execute_shell',
      arguments: double('Args', command:, monochrome:)
    ))
  end

  def stub_success(stdout: 'ok', stderr: '', exit_code: 0)
    allow(chat).to receive(:edit_text).and_return('ls')
    allow(chat).to receive(:confirm?).and_return('y')
    allow(chat).to receive(:use_pager) { |&blk| blk.call(StringIO.new) }
    allow(Open3).to receive(:capture3)
      .and_return([stdout, stderr, double('s', exitstatus: exit_code)])
  end

  describe 'identity' do
    it 'has the expected name' do
      expect(tool.name).to eq 'execute_shell'
    end

    it 'provides a Tool instance' do
      expect(tool.tool).to be_a(Ollama::Tool)
    end

    it 'can be converted to hash' do
      expect(tool.to_hash).to be_a(Hash)
    end
  end

  describe '#execute' do
    it 'runs the command after editor review and confirmation' do
      expect(chat).to receive(:edit_text)
        .with('ls -l', hash_including(basename: %w[cmd .sh]))
        .and_return('ls -l')
      expect(chat).to receive(:confirm?).and_return('y')
      allow(chat).to receive(:use_pager) { |&blk| blk.call(StringIO.new) }
      expect(Open3).to receive(:capture3)
        .with('sh', '-c', 'ls -l')
        .and_return(['total 0', '', double('s', exitstatus: 0)])

      result = tool.execute(tool_call('ls -l'), chat:)
      json   = json_object(result)

      expect(json.error).to be_nil
      expect(json.exit_code).to eq 0
      expect(json.stdout).to eq 'total 0'
      expect(json.stderr).to eq ''
      expect(json.command).to eq 'ls -l'
      expect(described_class.summary_template(result:)).to include('ls -l')
    end

    it 'executes the command as edited in the editor' do
      allow(chat).to receive(:use_pager) { |&blk| blk.call(StringIO.new) }
      expect(chat).to receive(:edit_text)
        .with('ls', anything)
        .and_return('ls -la /tmp')
      allow(chat).to receive(:confirm?).and_return('y')
      expect(Open3).to receive(:capture3)
        .with('sh', '-c', 'ls -la /tmp')
        .and_return(['x', '', double('s', exitstatus: 0)])

      result = tool.execute(tool_call('ls'), chat:)

      expect(json_object(result).command).to eq 'ls -la /tmp'
    end

    it 'returns cancelled when the user answers n' do
      allow(chat).to receive(:edit_text).and_return('rm -rf .')
      expect(chat).to receive(:confirm?).and_return('n')
      expect(Open3).not_to receive(:capture3)

      result = tool.execute(tool_call('rm -rf .'), chat:)
      json   = json_object(result)

      expect(json.error).to eq 'OllamaChat::ToolFunctionArgumentError'
      expect(json.message).to include('cancelled')
      expect(json.command).to eq 'rm -rf .'
    end

    it 'returns instruct when the user answers i' do
      allow(chat).to receive(:edit_text).and_return('rm -rf .')
      allow(chat).to receive(:confirm?).and_return('i')
      expect(chat).to receive(:ask?)
        .and_return('Actually use the build dir, not root')
      expect(Open3).not_to receive(:capture3)

      result = tool.execute(tool_call('rm -rf .'), chat:)
      json   = json_object(result)

      expect(json.error).to eq 'OllamaChat::ToolFunctionArgumentError'
      expect(json.command).to eq 'rm -rf .'
      expect(json.message).to include('build dir')
    end

    it 'returns cancelled when the editor is abandoned (nil)' do
      expect(chat).to receive(:edit_text).and_return(nil)
      expect(chat).not_to receive(:confirm?)
      expect(Open3).not_to receive(:capture3)

      result = tool.execute(tool_call('ls'), chat:)
      json   = json_object(result)

      expect(json.error).to eq 'OllamaChat::ToolFunctionArgumentError'
      expect(json.message).to include('cancelled')
      expect(json.command).to eq 'ls'
    end

    it 'returns cancelled when the editor is cleared to empty' do
      expect(chat).to receive(:edit_text).and_return('')
      expect(chat).not_to receive(:confirm?)
      expect(Open3).not_to receive(:capture3)

      result = tool.execute(tool_call('ls'), chat:)
      json   = json_object(result)

      expect(json.error).to eq 'OllamaChat::ToolFunctionArgumentError'
    end

    it 'skips editor and confirm in test mode' do
      expect(OllamaChat).to receive(:test_mode?).and_return(true)
      expect(chat).not_to receive(:edit_text)
      expect(chat).not_to receive(:confirm?)
      expect(Open3).to receive(:capture3)
        .with('sh', '-c', 'ls')
        .and_return(['ok', '', double('s', exitstatus: 0)])

      result = tool.execute(tool_call('ls'), chat:)

      expect(json_object(result).exit_code).to eq 0
    end

    it 'displays output via use_pager after execution' do
      stub_success(stdout: "file1\nfile2", stderr: '')
      pager_output = nil
      expect(chat).to receive(:use_pager) do |&blk|
        io = StringIO.new
        blk.call(io)
        pager_output = io.string
      end

      tool.execute(tool_call('ls'), chat:)

      expect(pager_output).to include('file1')
      expect(pager_output).to include('file2')
      expect(pager_output).to include('exit: 0')
    end

    it 'strips ANSI from stdout when monochrome is true' do
      stub_success(stdout: "\e[32mgreen\e[0m", stderr: '')

      result = tool.execute(tool_call('ls', monochrome: true), chat:)

      expect(json_object(result).stdout).to eq 'green'
    end

    it 'keeps ANSI when monochrome is false' do
      stub_success(stdout: "\e[32mgreen\e[0m", stderr: '')

      result = tool.execute(tool_call('ls', monochrome: false), chat:)

      expect(json_object(result).stdout).to eq "\e[32mgreen\e[0m"
    end

    it 'treats a nil monochrome as true (default)' do
      stub_success(stdout: "\e[31mred\e[0m", stderr: '')

      result = tool.execute(tool_call('ls', monochrome: nil), chat:)

      expect(json_object(result).stdout).to eq 'red'
    end

    it 'reports the exit code and stderr on failure' do
      stub_success(stdout: '', stderr: 'nope', exit_code: 2)

      result = tool.execute(tool_call('false'), chat:)
      json   = json_object(result)

      expect(json.exit_code).to eq 2
      expect(json.stderr).to eq 'nope'
    end

    it 'rejects a blank command' do
      allow(chat).to receive(:edit_text)

      result = tool.execute(tool_call(nil), chat:)
      json   = json_object(result)

      expect(json.error).to eq 'OllamaChat::ToolFunctionArgumentError'
    end

    it 'summary_template includes the command and exit code' do
      result = {
        stdout: 'x', stderr: '', exit_code: 0,
        command: 'ls -l', message: 'ok',
      }.to_json

      summary = described_class.summary_template(result:)
      expect(summary).to include('ls -l')
      expect(summary).to include('exit 0')
    end

    it 'summary_template includes error message for cancelled' do
      result = {
        error:   'OllamaChat::ToolFunctionArgumentError',
        command: 'rm -rf .',
        message: 'Shell command cancelled by user: rm -rf .',
      }.to_json

      summary = described_class.summary_template(result:)
      expect(summary).to include('cancelled')
      expect(summary).to include('rm -rf .')
    end

  end
end
