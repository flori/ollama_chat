require 'spec_helper'

describe OllamaChat::InputContent do
  let :chat do
    OllamaChat::Chat.new
  end

  connect_to_ollama_server

  describe '#input' do
    it 'can read content from a selected file' do
      selected_filename = 'spec/assets/example.rb'
      # Mock the file selection process
      expect(chat).to receive(:choose_filename).with('**/*', chosen: Set[]).
        and_return(selected_filename)
      expect(chat).to receive(:choose_filename).with('**/*', chosen: Set[selected_filename]).
        and_return nil

      # Test that it returns the file content
      result = chat.input(nil)
      expect(result).to include('puts "Hello World!"')
    end

    it 'returns nil when no file is selected' do
      expect(chat).to receive(:choose_filename).with('**/*', chosen: Set[]).
        and_return(nil)
      expect(chat.input(nil)).to be_nil
    end

    it 'can read content with specific pattern' do
      selected_filename = 'spec/assets/example.rb'
      expect(chat).to receive(:choose_filename).
        with('spec/assets/*', chosen: Set[]).
        and_return(selected_filename)
      expect(chat).to receive(:choose_filename).
        with('spec/assets/*', chosen: Set[selected_filename]).
        and_return nil
      result = chat.input('spec/assets/*')
      expect(result).to include('puts "Hello World!"')
    end
  end

  describe '#choose_filename' do
    it 'can select a file from matching patterns' do
      # Test with a pattern that matches existing files
      files = Dir.glob('spec/assets/*')
      expect(files).to_not be_empty

      # Mock the selection process
      expect(OllamaChat::Utils::Chooser).to receive(:choose).
        with(files.unshift('[EXIT]')).and_return(files[1])

      result = chat.choose_filename('spec/assets/*')
      expect(result).to eq files[1]
    end

    it 'returns nil when user exits selection' do
      expect(OllamaChat::Utils::Chooser).to receive(:choose).and_return(nil)
      expect(chat.choose_filename('spec/assets/*')).to be_nil
    end

    it 'returns nil when user chooses exit' do
      expect(OllamaChat::Utils::Chooser).to receive(:choose).and_return('[EXIT]')
      expect(chat.choose_filename('spec/assets/*')).to be_nil
    end
  end

  describe '#context_spook' do
    it 'can collect context with patterns' do
      # Test with specific patterns
      patterns = ['spec/assets/example.rb']
      expect(ContextSpook).to receive(:generate_context).with(hash_including(verbose: true))

      # This should not raise an error, but return nil since we're not mocking the full implementation
      expect { chat.context_spook(patterns) }.not_to raise_error
    end

    it 'can load default context when no patterns provided' do
      # Mock finding a context definition file
      filename = '.contexts/code_comment.rb'
      expect(chat).to receive(:choose_filename).with('.contexts/*.rb').
        and_return(filename)

      expect(ContextSpook).to receive(:generate_context).
        with(filename, hash_including(verbose: true))

      # This should not raise an error
      expect { chat.context_spook(nil) }.not_to raise_error
    end

    it 'returns nil when no context file is found' do
      expect(chat).to receive(:choose_filename).with('.contexts/*.rb').
        and_return(nil)
      expect(chat.context_spook(nil)).to be_nil
    end
  end

  describe '#compose' do
    it 'can open editor to compose content' do
      # Mock editor configuration
      const_conf_as('OllamaChat::EnvConfig::EDITOR' => '/usr/bin/vim')

      # Mock Tempfile behavior
      tmp_double = double('tmp', path: '/tmp/test')
      expect(Tempfile).to receive(:open).and_yield(tmp_double)

      # Mock system call to simulate successful editor execution
      expect(chat).to receive(:system).with('/usr/bin/vim "/tmp/test"').and_return(true)

      # Mock file reading to return content
      expect(File).to receive(:read).with('/tmp/test').and_return('composed content')

      result = chat.compose
      expect(result).to eq 'composed content'
    end

    it 'handles missing editor gracefully' do
      const_conf_as('OllamaChat::EnvConfig::EDITOR' => nil)

      expect(STDERR).to receive(:puts).with(/Editor required for compose/)
      expect(chat.compose).to be_nil
    end

    it 'handles editor failure' do
      const_conf_as('OllamaChat::EnvConfig::EDITOR' => '/usr/bin/vim')

      tmp_double = double('tmp', path: '/tmp/test')
      expect(Tempfile).to receive(:open).and_yield(tmp_double)

      expect(chat).to receive(:system).with('/usr/bin/vim "/tmp/test"').and_return(false)

      expect(STDERR).to receive(:puts).with(/Editor failed to edit/)
      expect(chat.compose).to be_nil
    end
  end
end
