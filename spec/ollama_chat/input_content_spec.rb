describe OllamaChat::InputContent do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config).expose
  end

  connect_to_ollama_server

  describe '#input' do
    it 'can read content from a selected file' do
      selected_filename = Pathname.new('spec/assets/example.rb')
      expect(chat).to receive(:choose_multiple_filenames)
        .and_return(Set[ selected_filename.expand_path ])

      result = chat.input(nil)
      expect(result).to include('puts "Hello World!"')
    end

    it 'returns nil when no file is selected' do
      expect(chat).to receive(:choose_multiple_filenames)
        .and_return(Set[])
      expect(chat.input(nil)).to be_nil
    end

    it 'can read content with specific pattern' do
      selected_filename = Pathname.new('spec/assets/example.rb')
      expect(chat).to receive(:choose_multiple_filenames)
        .and_return(Set[ selected_filename.expand_path ])
      result = chat.input('spec/assets/*')
      expect(result).to include('puts "Hello World!"')
    end
  end

  describe '#choose_filename' do
    it 'can select a file from matching patterns' do
      files = Pathname.glob('spec/assets/**/*.txt')
      expect(files).to_not be_empty

      # The picker surfaces size-annotated Wrappers; capture them and assert
      # on the underlying values so the spec doesn't couple to the display.
      presented = nil
      allow(chat).to receive(:choose_entry) do |entries, **_opts|
        presented = entries
        entries[1] # return the first real entry (a Wrapper)
      end

      result = chat.choose_filename('spec/assets/**/*.txt')

      expect(presented.first).to eq '[EXIT]'
      expect(presented.drop(1).map(&:value)).to match_array(files)
      expect(result).to be_a(Pathname)
    end

    it 'returns nil when user exits selection' do
      expect(chat).to receive(:choose_entry).and_return(nil)
      expect(chat.choose_filename('spec/assets/*')).to be_nil
    end

    it 'returns nil when user chooses exit' do
      expect(chat).to receive(:choose_entry).and_return('[EXIT]')
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

    it 'returns the serialized context instead of nil' do
      patterns = ['spec/assets/example.rb']
      expect(chat).to receive(:feedback).with(a_string_including('Ingesting context now'), type: :info)
      result = chat.context_spook(patterns, all: true)
      expect(result).to be_a(String)
      json     = JSON.parse(result)
      expected = Pathname.new('spec/assets/example.rb').expand_path.to_path
      expect(json['files'].keys).to include(expected)
    end
  end
end
