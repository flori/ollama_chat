describe OllamaChat::Vim do
  let(:server_name) { 'TEST_SERVER' }
  let(:vim) { described_class.new(server_name).expose }

  let(:ok_status) { instance_double(Process::Status, success?: true) }
  let(:fail_status) { instance_double(Process::Status, success?: false) }

  let(:state_expr) { "[&modifiable, line('.'), col('.')]" }

  describe '#initialize' do
    it 'can be initialized with a server name' do
      expect(vim.server_name).to eq server_name
    end

    it 'can be initialized without a server name' do
      vim_without_name = described_class.new(nil)
      expect(vim_without_name.server_name).to be_a(String)
    end

    it 'uses socket as default clientserver protocol' do
      expect(vim.clientserver).to eq 'socket'
    end

    it 'can specify clientserver protocol' do
      vim_with_protocol = described_class.new(server_name, clientserver: 'pipe')
      expect(vim_with_protocol.clientserver).to eq 'pipe'
    end
  end

  describe '.default_server_name' do
    it 'generates a standardized server name from a directory' do
      name = described_class.default_server_name('/path/to/project')
      expect(name).to match(/\A[A-Z0-9]+-[A-Z0-9]+\z/)
      expect(name).to include('PROJECT')
    end

    it 'handles current working directory' do
      name = described_class.default_server_name
      expect(name).to be_a(String)
      expect(name).to_not be_empty
    end

    it 'generates consistent names for same path' do
      name1 = described_class.default_server_name('/tmp/test')
      name2 = described_class.default_server_name('/tmp/test')
      expect(name1).to eq name2
    end
  end

  describe 'State' do
    describe '#modifiable?' do
      it 'returns true when modifiable is 1' do
        info = described_class::State.new(modifiable: 1, line: 3, col: 5)
        expect(info.modifiable?).to be true
      end

      it 'returns false when modifiable is 0' do
        info = described_class::State.new(modifiable: 0, line: 3, col: 5)
        expect(info.modifiable?).to be false
      end
    end

    describe '#cursor_present?' do
      it 'returns true when col > 0' do
        info = described_class::State.new(modifiable: 1, line: 3, col: 1)
        expect(info.cursor_present?).to be true
      end

      it 'returns false when col is 0' do
        info = described_class::State.new(modifiable: 1, line: 0, col: 0)
        expect(info.cursor_present?).to be false
      end
    end
  end

  describe '#current_state' do
    it 'returns a State when server is up' do
      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name, '--remote-expr', state_expr
      ).and_return(["[1, 3, 5]\n", "", ok_status])

      info = vim.current_state
      expect(info).to be_a(described_class::State)
      expect(info.modifiable).to eq 1
      expect(info.line).to eq 3
      expect(info.col).to eq 5
    end

    it 'returns nil when server is down' do
      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name, '--remote-expr', state_expr
      ).and_return(["", "", ok_status])

      expect(vim.current_state).to be_nil
    end
  end

  describe '#server_running?' do
    it 'returns true when cursor is present' do
      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name, '--remote-expr', state_expr
      ).and_return(["[1, 7, 10]\n", "", ok_status])

      expect(vim.server_running?).to be true
    end

    it 'returns false when server is down' do
      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name, '--remote-expr', state_expr
      ).and_return(["", "", ok_status])

      expect(vim.server_running?).to be false
    end

    it 'returns false when col is 0' do
      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name, '--remote-expr', state_expr
      ).and_return(["[1, 0, 0]\n", "", ok_status])

      expect(vim.server_running?).to be false
    end
  end

  describe '#insert' do
    it 'indents text and returns a successful Result' do
      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name, '--remote-expr', state_expr
      ).and_return(["[1, 3, 5]\n", "", ok_status])

      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name,
        '--remote-send', "\<ESC\>:r /tmp/test\<CR\>"
      ).and_return(["", "", ok_status])

      tmp = instance_double(Tempfile, flush: true, path: '/tmp/test')
      expect(Tempfile).to receive(:open).and_yield(tmp)
      expect(tmp).to receive(:write).with("    test content")

      result = vim.insert('test content')
      expect(result).to be_a(described_class::Result)
      expect(result.status.success?).to be true
    end

    it 'returns a failed Result with stderr' do
      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name, '--remote-expr', state_expr
      ).and_return(["[1, 1, 1]\n", "", ok_status])

      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name,
        '--remote-send', "\<ESC\>:r /tmp/test\<CR\>"
      ).and_return(["", "vim: E5108: channel error\n", fail_status])

      tmp = instance_double(Tempfile, flush: true, path: '/tmp/test')
      expect(Tempfile).to receive(:open).and_yield(tmp)
      expect(tmp).to receive(:write)

      result = vim.insert('hello')
      expect(result.status.success?).to be false
      expect(result.stderr).to include("E5108")
    end

    it 'raises VimError when buffer is not modifiable' do
      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name, '--remote-expr', state_expr
      ).and_return(["[0, 3, 5]\n", "", ok_status])

      expect { vim.insert('hello') }
        .to raise_error(OllamaChat::VimError, /not modifiable/)
    end

    it 'raises VimError when server is not running' do
      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name, '--remote-expr', state_expr
      ).and_return(["", "", ok_status])

      expect { vim.insert('hello') }
        .to raise_error(OllamaChat::VimError, /is not running/)
    end
  end

  describe '#open_file' do
    it 'raises VimError when server is down' do
      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name, '--remote-expr', state_expr
      ).and_return(["", "", ok_status])

      expect { vim.open_file('/tmp/test.rb') }
        .to raise_error(OllamaChat::VimError, /is not running/)
    end

    it 'returns a successful Result in center mode' do
      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name, '--remote-expr', state_expr
      ).and_return(["[1, 1, 1]\n", "", ok_status])

      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name, '--remote', '+5', '/tmp/test.rb'
      ).and_return(["", "", ok_status])

      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name, '--remote-send', '<ESC>zz'
      ).and_return(["", "", ok_status])

      result = vim.open_file('/tmp/test.rb', 5)
      expect(result).to be_a(described_class::Result)
      expect(result.status.success?).to be true
    end

    it 'returns a failed Result early if --remote fails' do
      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name, '--remote-expr', state_expr
      ).and_return(["[1, 1, 1]\n", "", ok_status])

      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name, '--remote', '+1', '/tmp/test.rb'
      ).and_return(["", "vim: E325: ATTENTION\n", fail_status])

      result = vim.open_file('/tmp/test.rb')
      expect(result.status.success?).to be false
      expect(result.stderr).to include("E325")
    end

    it 'marks a range when end_line is given' do
      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name, '--remote-expr', state_expr
      ).and_return(["[1, 1, 1]\n", "", ok_status])

      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name, '--remote', '+3', '/tmp/test.rb'
      ).and_return(["", "", ok_status])

      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name,
        '--remote-send', "\<ESC\>:normal 3GV10G\<CR\>"
      ).and_return(["", "", ok_status])

      result = vim.open_file('/tmp/test.rb', 3, 10)
      expect(result).to be_a(described_class::Result)
      expect(result.status.success?).to be true
    end
  end
end
