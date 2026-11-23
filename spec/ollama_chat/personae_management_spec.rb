describe OllamaChat::PersonaeManagement do
  let :argv do
    chat_default_config
  end

  let :chat do
    OllamaChat::Chat.new(argv:).expose
  end

  connect_to_ollama_server

  describe '#sync_trigger' do
    it 'rekeys trigger when persona changes' do
      # After init, trigger points to the config default persona
      default_collection = "memory-#{chat.session.default_persona_name}"
      expect(chat.session.trigger&.each_pair&.first&.first&.to_s).to eq(default_collection)

      chat.set_default_persona_name('sarah')

      expect(chat.session.trigger&.each_pair&.first&.first&.to_s).to eq('memory-sarah')
      expect(chat.default_persona_name).to eq('sarah')
    end

    it 'sets trigger to nil when persona is :none' do
      chat.set_default_persona_name(:none)

      expect(chat.session.trigger).to be_nil
      expect(chat.default_persona_name).to be_nil
    end

    it 're-seeds trigger from config when switching from :none' do
      chat.set_default_persona_name(:none)
      expect(chat.session.trigger).to be_nil

      chat.set_default_persona_name('sarah')

      cfg = chat.session.trigger&.each_pair&.first&.last
      expect(cfg['enabled']).to be true
      expect(cfg['prompt_name']).to eq('memory_rerank')
    end

    it 'preserves existing trigger config on rekey' do
      chat.session.update(trigger: {
        "memory-#{chat.session.default_persona_name}" => {
          'enabled'     => false,
          'prompt_name' => 'memory_rerank',
          'text_count'  => 5
        }
      })

      chat.set_default_persona_name('sarah')

      cfg = chat.session.trigger&.each_pair&.first&.last
      expect(cfg['enabled']).to eq(false)
      expect(cfg['prompt_name']).to eq('memory_rerank')
      expect(cfg['text_count']).to eq(5)
    end

    it 'is idempotent when called with the same persona' do
      chat.set_default_persona_name('sarah')
      trigger_before = chat.session.trigger.dup

      chat.set_default_persona_name('sarah')

      expect(chat.session.trigger).to eq(trigger_before)
      expect(chat.session.trigger&.each_pair&.first&.first&.to_s).to eq('memory-sarah')
    end
  end
end
