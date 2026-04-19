describe OllamaChat::InputContent do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config).expose
  end

  connect_to_ollama_server

  describe '#edit_text' do
    it 'can open editor to compose content' do
      # Mock editor configuration
      const_conf_as('OC::EDITOR' => '/usr/bin/vim')

      # Mock Tempfile behavior
      tmp_double = double('tmp', path: '/tmp/test')
      expect(Tempfile).to receive(:create).and_yield(tmp_double)

      # Mock system call to simulate successful editor execution
      expect(chat).to receive(:system).with('/usr/bin/vim /tmp/test').and_return(true)

      # Mock file reading to return content
      expect(File).to receive(:read).with('/tmp/test').and_return('composed content')

      result = chat.edit_text
      expect(result).to eq 'composed content'
    end

    it 'handles missing editor gracefully' do
      const_conf_as('OC::EDITOR' => nil)

      expect(STDERR).to receive(:puts).with(/Need the environment variable var EDITOR/)
      expect(STDERR).to receive(:puts).with(/Editor failed to edit/)
      expect(chat.edit_text).to be_nil
    end

    it 'handles editor failure' do
      const_conf_as('OC::EDITOR' => '/usr/bin/vim')

      tmp_double = double('tmp', path: '/tmp/test')
      expect(Tempfile).to receive(:create).and_yield(tmp_double)

      expect(chat).to receive(:system).with('/usr/bin/vim /tmp/test').and_return(false)

      expect(STDERR).to receive(:puts).with(/Editor failed to edit/)
      expect(chat.edit_text).to be_nil
    end
  end
end
