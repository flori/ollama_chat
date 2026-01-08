require 'spec_helper'

describe OllamaChat::Vim do
  let(:server_name) { 'TEST_SERVER' }
  let(:vim) { described_class.new(server_name) }

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

  describe '#insert' do
    it 'can insert text into vim' do
      expect(vim).to receive(:`).with(
        /vim.*--remote-expr.*col\('\.'\)/
      ).and_return("5\n")
      # Mock the system call to avoid actual vim interaction
      expect(vim).to receive(:system).with(
        /vim.*--servername.*#{server_name}.*--remote-send/
      )
      vim.insert('test content')
    end

    it 'handles text indentation' do
      # Mock the col method to return a specific column
      expect(vim).to receive(:`).with(
        /vim.*--remote-expr.*col\('\.'\)/).and_return("5\n"
                                                     )
      tmp = double('Tempfile', flush: true, path: '/tmp/test')
      expect(Tempfile).to receive(:open).and_yield(tmp)
      expect(tmp).to receive(:write).with('    test content')
      expect(vim).to receive(:system).with(
        /vim --clientserver.*--servername.*--remote-send.*\/tmp\/test/
      ).and_return true
      vim.insert('test content')
    end
  end

  describe '#col' do
    it 'can get current column position' do
      # Mock the system call to return a specific column
      expect(vim).to receive(:`).with(
        /vim.*--remote-expr.*col\('\.'\)/
      ).and_return("5\n")
      expect(vim.col).to eq 5
    end

    it 'handles empty response' do
      expect(vim).to receive(:`).and_return("\n")
      expect(vim.col).to eq 0
    end
  end
end
