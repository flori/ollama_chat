describe OllamaChat::ConfigHandling do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config).expose
  end

  connect_to_ollama_server

  before do
    const_conf_as('OC::PAGER' => nil)
  end

  describe '#config' do
    it 'returns a ComplexConfig::Settings instance' do
      expect(chat.config).to be_a(ComplexConfig::Settings)
    end

    it 'delegates to the class-level accessor' do
      expect(chat.config).to be(OllamaChat::Chat.config)
    end
  end

  describe '#config=' do
    it 'stores the config at the class level' do
      new_config = double('ComplexConfig::Settings')
      original   = OllamaChat::Chat.config
      chat.config = new_config
      expect(chat.config).to be(new_config)
    ensure
      OllamaChat::Chat.config = original
    end
  end

  describe '#display_config' do
    it 'renders the config through the ANSI pager' do
      lines = "line1\nline2\nline3"
      expect(chat.config).to receive(:to_s).and_return(lines)
      expect(STDOUT).to receive(:puts).with(lines)
      expect { chat.display_config }.not_to raise_error
    end
  end

  describe '#fix_session' do
    let(:session_id) { '99' }

    before do
      expect(chat).to receive(:session).
        and_return(double('session', id: session_id))
    end

    it 'appends -l <id> when no -l flag is present' do
      argv = %w[-m llama3]
      expect(chat.fix_session(argv)).to eq(%w[-m llama3 -l 99])
      expect(argv).to eq(%w[-m llama3]) # original unmodified
    end

    it 'replaces an existing -l value with the current session id' do
      expect(chat.fix_session(%w[-l old_id -m llama3]))
        .to eq(%w[-l 99 -m llama3])
    end

    it 'inserts the session id when -l is the last element' do
      expect(chat.fix_session(%w[-m llama3 -l])).to eq(%w[-m llama3 -l 99])
    end
  end

  describe '#fix_config' do
    let(:exception) { StandardError.new('bad yaml') }

    context 'without a diff tool' do
      before do
        expect(OC).to receive(:DIFF_TOOL?).and_return(nil)
      end

      it 'prints the error and exits with status 1' do
        expect(STDOUT).to receive(:puts)
          .with(/When reading the config file.*bad yaml/)
        expect(chat).to receive(:exit).with(1).at_least(:once)
          .and_raise("simulated exit 1")
        expect {
          chat.fix_config(exception)
        }.to raise_error("simulated exit 1")
      end
    end

    context 'with a diff tool' do
      before { const_conf_as('OC::DIFF_TOOL' => 'vimdiff') }

      it 'launches the diff tool and exits 0 on confirmation' do
        expect(chat).to receive(:confirm?).and_return(true)
        expect(STDOUT).to receive(:puts)
          .with(/When reading the config file/)
        expect(chat).to receive(:system).with('vimdiff', any_args)
        expect(chat).to receive(:exit).with(0)
          .and_raise("simulated exit 0")
        expect {
          chat.fix_config(exception)
        }.to raise_error("simulated exit 0")
      end

      it 'exits with status 1 when the user declines' do
        expect(chat).to receive(:confirm?).and_return(false)
        expect(STDOUT).to receive(:puts)
          .with(/When reading the config file/)
        expect(chat).to receive(:exit).with(1)
          .and_raise("simulated exit 1")
        expect {
          chat.fix_config(exception)
        }.to raise_error("simulated exit 1")
      end
    end
  end

  describe '#diff_config' do
    context 'without a diff tool' do
      before do
        expect(OC).to receive(:DIFF_TOOL?).and_return(nil)
      end

      it 'prints an error to STDERR and returns nil' do
        expect(STDERR).to receive(:puts).with(/No diff tool configured/)
        expect(chat.diff_config).to be_nil
      end
    end

    context 'with a diff tool' do
      before { const_conf_as('OC::DIFF_TOOL' => 'vimdiff') }

      it 'launches the diff tool with config and default paths' do
        expect(chat.instance_variable_get(:@ollama_chat_config))
          .to receive(:filename).and_return('/cfg.yml')
          .ordered
        expect(chat.instance_variable_get(:@ollama_chat_config))
          .to receive(:default_config_path).and_return('/default.yml')
          .ordered
        expect(chat).to receive(:system)
          .with('vimdiff', '/cfg.yml', '/default.yml')
          .and_return(true)
        expect(chat.diff_config).to be true
      end
    end
  end

  describe '#edit_config' do
    it 'edits the config and restarts on confirmation' do
      expect(chat).to receive(:edit_file).and_return(true)
      expect(chat).to receive(:confirm?).and_return(true)
      expect(chat).to receive(:session_close)
      expect(chat).to receive(:exec).with(any_args)
      chat.edit_config
    end

    it 'skips restart when the user declines' do
      expect(chat).to receive(:edit_file).and_return(true)
      expect(chat).to receive(:confirm?).and_return(false)
      expect(STDOUT).to receive(:puts).with(/Skipped reloading/)
      chat.edit_config
    end

    it 'reports a non-zero editor exit' do
      expect(chat).to receive(:edit_file).and_return(nil)
      expect(STDERR).to receive(:puts).with(/non-zero status/)
      chat.edit_config
    end
  end

  describe '#reload_config' do
    it 'closes the session and execs on confirmation' do
      expect(chat).to receive(:confirm?).and_return(true)
      expect(chat).to receive(:session_close)
      expect(chat).to receive(:exec).with(any_args)
      chat.reload_config
    end

    it 'prints a skip message when the user declines' do
      expect(chat).to receive(:confirm?).and_return(false)
      expect(STDOUT).to receive(:puts).with(/Skipped reloading/)
      chat.reload_config
    end
  end

  describe '#syntax_checker_for' do
    it 'returns the matching enabled checker for a .rb file' do
      checker = chat.syntax_checker_for('./foo.rb')
      expect(checker).to be_a(ComplexConfig::Settings)
      expect(checker.suffixes).to include('rb')
    end

    it 'matches .rake and .gemspec extensions' do
      expect(chat.syntax_checker_for('./Rakefile.rake'))
        .to be_a(ComplexConfig::Settings)
      expect(chat.syntax_checker_for('./x.gemspec'))
        .to be_a(ComplexConfig::Settings)
    end

    it 'returns nil for an unmatched extension' do
      expect(chat.syntax_checker_for('./foo.txt')).to be_nil
    end

    it 'returns nil when the file has no extension' do
      expect(chat.syntax_checker_for('./Makefile')).to be_nil
    end

    it 'returns nil for a disabled checker' do
      expect(chat.syntax_checker_for('./foo.py')).to be_nil
    end
  end

  describe '#run_syntax_check' do
    let :checker do
      double('checker', cmd: %w[ruby -wc])
    end

    it 'returns a pass result for valid Ruby' do
      require 'tmpdir'
      Dir.mktmpdir do |dir|
        file = File.join(dir, 'ok.rb')
        File.write(file, "puts 'hi'\n")
        result = chat.run_syntax_check(checker, file)
        expect(result[:status]).to eq 'pass'
        expect(result[:output]).to eq ''
      end
    end

    it 'returns a fail result for broken Ruby' do
      require 'tmpdir'
      Dir.mktmpdir do |dir|
        file = File.join(dir, 'bad.rb')
        File.write(file, "def broken\n")
        result = chat.run_syntax_check(checker, file)
        expect(result[:status]).to eq 'fail'
        expect(result[:output]).to include('syntax error')
      end
    end

    it 'returns nil when the binary is missing' do
      no_binary = double('checker', cmd: %w[nonexistent_checker_xyz -n])
      expect(chat.run_syntax_check(no_binary, './foo')).to be_nil
    end
  end
end
