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
end
