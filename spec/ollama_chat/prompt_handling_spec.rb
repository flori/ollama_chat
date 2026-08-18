describe OllamaChat::PromptHandling do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config).expose
  end

  connect_to_ollama_server

  let :prompt_model do
    chat::models::Prompt
  end

  describe '#prompt' do
    it 'finds a prompt by name and context' do
      obj = prompt_model.create(context: 'prompt', name: 'zz_lookup',
                                metadata: { default: false, content: 'hello' })

      found = chat.prompt('zz_lookup')

      expect(found.id).to eq(obj.id)
      expect(found.name).to eq('zz_lookup')
    end

    it 'accepts a symbol name' do
      obj = prompt_model.create(context: 'prompt', name: 'zz_sym',
                                metadata: { default: false, content: 'x' })

      expect(chat.prompt(:zz_sym).id).to eq(obj.id)
    end

    it 'respects a custom context' do
      obj = prompt_model.create(context: 'system', name: 'zz_sys',
                                metadata: { default: false, content: 'y' })

      expect(chat.prompt('zz_sys', context: 'system').id).to eq(obj.id)
    end

    it 'returns nil when no prompt matches' do
      expect(chat.prompt('zz_does_not_exist')).to be_nil
    end
  end

  describe '#each_prompt' do
    before do
      prompt_model.create(context: 'prompt', name: 'zz_each_a',
                          metadata: { default: true, content: 'A' })
      prompt_model.create(context: 'prompt', name: 'zz_each_b',
                          metadata: { default: false, content: 'B' })
    end

    it 'yields prompts of the given context' do
      yielded = []
      chat.each_prompt { |p| yielded << p.name }

      expect(yielded).to include('zz_each_a', 'zz_each_b')
    end

    it 'returns an enumerator when no block is given' do
      result = chat.each_prompt

      expect(result).to be_a(Enumerator)
      expect(result.map(&:name)).to include('zz_each_a', 'zz_each_b')
    end

    it 'filters to default prompts when default: true' do
      result = chat.each_prompt(default: true).map(&:name)

      expect(result).to include('zz_each_a')
      expect(result).not_to include('zz_each_b')
    end

    it 'filters to non-default prompts when default: false' do
      result = chat.each_prompt(default: false).map(&:name)

      expect(result).to include('zz_each_b')
      expect(result).not_to include('zz_each_a')
    end

    it 'scopes by context' do
      prompt_model.create(context: 'system', name: 'zz_each_sys',
                          metadata: { default: false, content: 'S' })

      result = chat.each_prompt(context: 'system').map(&:name)

      expect(result).to include('zz_each_sys')
      expect(result).not_to include('zz_each_a')
    end
  end

  describe '#delete_prompt' do
    it 'deletes a non-default prompt and returns true' do
      obj = prompt_model.create(context: 'prompt', name: 'zz_del',
                                metadata: { default: false, content: 'x' })

      expect(chat.delete_prompt('zz_del')).to be true
      expect(prompt_model.where(id: obj.id)).to be_empty
    end

    it 'refuses to delete a default prompt' do
      obj = prompt_model.create(context: 'prompt', name: 'zz_def',
                                metadata: { default: true, content: 'x' })

      expect(chat.delete_prompt('zz_def')).to be false
      expect(prompt_model.where(id: obj.id)).not_to be_empty
    end

    it 'returns false for a nonexistent prompt' do
      expect(chat.delete_prompt('zz_missing')).to be false
    end
  end

  describe '#store_prompt' do
    it 'persists a new prompt' do
      chat.store_prompt('zz_store', 'content-here')

      obj = prompt_model.where(name: 'zz_store', context: 'prompt').first
      expect(obj).not_to be_nil
      expect(obj.metadata['content']).to eq('content-here')
    end

    it 'respects a custom context' do
      chat.store_prompt('zz_store_sys', 'content-sys', context: 'system')

      obj = prompt_model.where(name: 'zz_store_sys', context: 'system').first
      expect(obj).not_to be_nil
    end
  end

  describe '#write_prompt' do
    it 'creates a prompt with default: false when it does not exist' do
      obj = chat.write_prompt('zz_write', 'initial', context: 'prompt')

      expect(obj.name).to eq('zz_write')
      expect(obj.metadata['default']).to be false
      expect(obj.metadata['content']).to eq('initial')
    end

    it 'updates content on an existing prompt' do
      chat.write_prompt('zz_upd', 'v1')
      updated = chat.write_prompt('zz_upd', 'v2')

      expect(prompt_model.where(name: 'zz_upd').count).to eq(1)
      expect(updated.metadata['content']).to eq('v2')
    end


  end

  describe '#load_prompt_from_file' do
    let :temp_file do
      Pathname(__dir__).join('..', 'assets', 'prompt_file.txt')
    end

    before do
      File.write(temp_file, 'file-based prompt content')
    end

    after do
      temp_file.delete if temp_file.exist?
    end

    it 'reads and returns the content of the chosen file' do
      expect(chat).to receive(:choose_filename).and_return(temp_file)
      expect(chat).to receive(:log)

      expect(chat.load_prompt_from_file).to eq('file-based prompt content')
    end

    it 'returns nil when no file was chosen' do
      expect(chat).to receive(:choose_filename).and_return(nil)
      expect(chat).to receive(:log)

      expect(chat.load_prompt_from_file).to be_nil
    end

    it 'passes the given patterns to choose_filename' do
      expect(chat).to receive(:choose_filename).with(['**/*.{txt,md}'])
        .and_return(nil)
      expect(chat).to receive(:log)

      chat.load_prompt_from_file
    end
  end
end
