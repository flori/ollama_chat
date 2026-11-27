describe OllamaChat::Vim do
  let(:server_name) { 'TEST_SERVER' }
  let(:vim) { described_class.new(server_name) }

  let(:ok_status) { instance_double(Process::Status, success?: true) }
  let(:fail_status) { instance_double(Process::Status, success?: false) }

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

  describe '#col' do
    it 'returns a Result with stdout captured' do
      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name, '--remote-expr', "col('.')"
      ).and_return(["5\n", "", ok_status])

      result = vim.col
      expect(result).to be_a(described_class::Result)
      expect(result.stdout).to eq "5\n"
      expect(result.stderr).to eq ""
    end

    it 'returns a Result with stderr on failure' do
      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name, '--remote-expr', "col('.')"
      ).and_return(["", "vim: E5108: channel error\n", fail_status])

      result = vim.col
      expect(result.stdout).to eq ""
      expect(result.stderr).to include("E5108")
      expect(result.status.success?).to be false
    end
  end

  describe '#server_running?' do
    it 'returns true when col succeeds and is > 0' do
      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name, '--remote-expr', "col('.')"
      ).and_return(["10\n", "", ok_status])

      expect(vim.server_running?).to be true
    end

    it 'returns false when the command fails' do
      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name, '--remote-expr', "col('.')"
      ).and_return(["", "vim: E5108\n", fail_status])

      expect(vim.server_running?).to be false
    end

    it 'returns false when col is 0' do
      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name, '--remote-expr', "col('.')"
      ).and_return(["0\n", "", ok_status])

      expect(vim.server_running?).to be false
    end
  end

  describe '#insert' do
    it 'indents text and returns a successful Result' do
      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name, '--remote-expr', "col('.')"
      ).and_return(["5\n", "", ok_status])

      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name,
        '--remote-send', "<ESC>:r /tmp/test<CR>"
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
        '--servername', server_name, '--remote-expr', "col('.')"
      ).and_return(["1\n", "", ok_status])

      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name,
        '--remote-send', "<ESC>:r /tmp/test<CR>"
      ).and_return(["", "vim: E5108: channel error\n", fail_status])

      tmp = instance_double(Tempfile, flush: true, path: '/tmp/test')
      expect(Tempfile).to receive(:open).and_yield(tmp)
      expect(tmp).to receive(:write)

      result = vim.insert('hello')
      expect(result.status.success?).to be false
      expect(result.stderr).to include("E5108")
    end
  end

  describe '#open_file' do
    it 'returns nil and emits feedback when server is down' do
      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name, '--remote-expr', "col('.')"
      ).and_return(["", "vim: E5108\n", fail_status])

      expect(vim).to receive(:feedback)
        .with(/Failed! Vim has to be running/, type: :warn)

      expect(vim.open_file('/tmp/test.rb')).to be_nil
    end

    it 'returns a successful Result in center mode' do
      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name, '--remote-expr', "col('.')"
      ).and_return(["1\n", "", ok_status])

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
        '--servername', server_name, '--remote-expr', "col('.')"
      ).and_return(["1\n", "", ok_status])

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
        '--servername', server_name, '--remote-expr', "col('.')"
      ).and_return(["1\n", "", ok_status])

      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name, '--remote', '+3', '/tmp/test.rb'
      ).and_return(["", "", ok_status])

      expect(Open3).to receive(:capture3).with(
        'vim', '--clientserver', 'socket',
        '--servername', server_name,
        '--remote-send', "<ESC>:normal 3GV10G<CR>"
      ).and_return(["", "", ok_status])

      result = vim.open_file('/tmp/test.rb', 3, 10)
      expect(result).to be_a(described_class::Result)
      expect(result.status.success?).to be true
    end
  end
end
