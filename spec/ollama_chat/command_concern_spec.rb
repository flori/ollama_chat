describe OllamaChat::CommandConcern do
  let(:commands) { OllamaChat::Commands }

  describe '.help_message' do
    it 'returns a Terminal::Table with all commands' do
      table = commands.help_message
      expect(table).to be_a(Terminal::Table)
      text = table.to_s
      expect(text).to include('CMD')
      expect(text).to include('copy')
      expect(text).to include('session')
    end

    it 'inserts bold category headers' do
      text = commands.help_message.to_s
      expect(text).to include('Clipboard')
      expect(text).to include('Session')
      expect(text).to include('Settings')
    end

    it 'filters commands by pattern' do
      text = commands.help_message(Regexp.new('copy')).to_s
      expect(text).to include('copy')
      expect(text).not_to include('session')
    end

    it 'includes subcommand expansions in the SUBCMD column' do
      text = commands.help_message(Regexp.new('config')).to_s
      expect(text).to include('edit')
      expect(text).to include('diff')
      expect(text).to include('reload')
      expect(text).to include('env')
    end

    it 'marks non-optional commands with the asterisk' do
      text = commands.help_message(Regexp.new('change')).to_s
      expect(text).to include("response﹡")
    end

    it 'does not mark optional commands with the asterisk' do
      text = commands.help_message(Regexp.new('config')).to_s
      expect(text).not_to include("﹡")
    end
  end

  describe '.command_completions' do
    let(:completions) { commands.command_completions }

    it 'returns an array of strings' do
      expect(completions).to be_an(Array)
      expect(completions).to all(be_a(String))
    end

    it 'includes bare command names for optional commands' do
      expect(completions).to include('/config')
      expect(completions).to include('/tools')
    end

    it 'includes subcommand expansions' do
      expect(completions).to include('/config edit')
      expect(completions).to include('/config diff')
      expect(completions).to include('/session model options change')
    end

    it 'includes bare names for commands without subcommands' do
      expect(completions).to include('/copy')
      expect(completions).to include('/quit')
    end

    it 'is sorted with bare names before subcommand variants' do
      config_entries = completions.grep(/^\/config/)
      expect(config_entries.first).to eq('/config')
    end
  end

  describe OllamaChat::CommandConcern::Command do
    let(:cmd) do
      described_class.new(
        name: :test,
        regexp: %r(^/test(?:\s+(-e))?\s*$),
        complete: ['test', %w[-e]],
        optional: true,
        options: '[-e]',
        help: 'A test command',
        category: :Test
      ) { :executed }
    end

    describe '#execute_if_match?' do
      it 'returns the command block result on match' do
        result = cmd.execute_if_match?('/test -e') { }
        expect(result).to eq :executed
      end

      it 'passes regexp captures to the command block' do
        capturing = described_class.new(
          name: :cap,
          regexp: %r(^/cap\s+(\w+)$),
          help: 'capture',
          category: :Test
        ) { |arg| "got:#{arg}" }
        result = capturing.execute_if_match?('/cap hello') { }
        expect(result).to eq 'got:hello'
      end

      it 'returns nil on no match' do
        expect(cmd.execute_if_match?('/nomatch') { }).to be_nil
      end

      it 'raises without a context block' do
        expect { cmd.execute_if_match?('/test') }.
          to raise_error(ArgumentError, /need &context/)
      end

      it 'executes on nil regexp with nil content' do
        bare = described_class.new(
          name: :bare, regexp: nil, help: 'bare', category: :Test
        ) { :bare_result }
        expect(bare.execute_if_match?(nil) { }).to eq :bare_result
      end

      it 'does not execute on nil regexp with non-nil content' do
        bare = described_class.new(
          name: :bare, regexp: nil, help: 'bare', category: :Test
        ) { :bare_result }
        expect(bare.execute_if_match?('hello') { }).to be_nil
      end
    end

    describe '#completions' do
      it 'includes product of names and arguments' do
        expect(cmd.completions).to include(['/test', '-e'])
      end

      it 'includes bare names when optional' do
        expect(cmd.completions).to include(['/test'])
      end

      it 'omits bare names when not optional' do
        strict = described_class.new(
          name: :strict,
          regexp: %r(^/strict\s+\S+),
          complete: ['strict', %w[arg1]],
          optional: false,
          help: 'strict',
          category: :Test
        ) { :ok }
        expect(strict.completions).not_to include(['/strict'])
        expect(strict.completions).to include(['/strict', 'arg1'])
      end
    end

    describe '#command_names' do
      it 'returns the first element of complete' do
        expect(cmd.command_names).to eq ['test']
      end
    end

    describe '#optional?' do
      it 'reflects the optional flag' do
        expect(cmd.optional?).to be true
      end
    end
  end

  describe 'duplicate registration' do
    it 'raises ArgumentError for same name twice' do
      expect(OllamaChat::Commands.commands).to have_key(:copy)
      expect {
        OllamaChat::Commands.command(name: :copy, regexp: %r(^/copy$), help: 'x') { :ok }
      }.to raise_error(ArgumentError, /already registered/)
    end
  end
end
