require 'spec_helper'

describe OllamaChat::MessageEditing do
  let :chat do
    OllamaChat::Chat.new argv: chat_default_config
  end

  connect_to_ollama_server

  describe '#revise_last' do
    it 'can revise the last message' do
      # First add a message to work with
      chat.messages << Ollama::Message.new(role: 'assistant', content: 'original content')

      const_conf_as('OllamaChat::EnvConfig::EDITOR' => '/usr/bin/vim')

      # Mock Tempfile behavior to simulate editor interaction
      tmp_double = double('tmp', write: true, flush: true, path: '/tmp/test')
      expect(Tempfile).to receive(:open).and_yield(tmp_double)

      # Mock system call to simulate successful editor execution
      expect(chat).to receive(:system).with('/usr/bin/vim "/tmp/test"').and_return(true)

      # Mock file reading to return edited content
      expect(File).to receive(:read).with('/tmp/test').and_return('edited content')

      # The method should return the edited content
      expect(chat.revise_last).to eq 'edited content'
    end

    it 'handles missing last message' do
      expect(STDERR).to receive(:puts).with(/No message available to revise/)
      expect(chat.revise_last).to be_nil
    end

    it 'handles missing editor gracefully' do
      chat.messages << Ollama::Message.new(role: 'assistant', content: 'original content')

      const_conf_as('OllamaChat::EnvConfig::EDITOR' => nil)

      expect(STDERR).to receive(:puts).with(/Editor required for revise/)
      expect(chat.revise_last).to be_nil
    end

    it 'handles no messages to revise' do
      # Clear messages array
      chat.instance_variable_get(:@messages).clear

      expect(STDERR).to receive(:puts).with(/No message available to revise/)
      expect(chat.revise_last).to be_nil
    end

    it 'handles editor failure' do
      const_conf_as('OllamaChat::EnvConfig::EDITOR' => '/usr/bin/vim')
      chat.messages << Ollama::Message.new(role: 'assistant', content: 'original content')
      tmp_double = double('tmp', write: true, flush: true, path: '/tmp/test')
      expect(Tempfile).to receive(:open).and_yield(tmp_double)
      expect(chat).to receive(:system).with('/usr/bin/vim "/tmp/test"').and_return(false)
      expect(STDERR).to receive(:puts).with(/Editor failed to edit message/)
      expect(chat.revise_last).to be_nil
    end
  end
end
