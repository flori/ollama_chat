describe OllamaChat::SystemPromptManagement do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config).expose
  end

  connect_to_ollama_server

  let :prompt_model do
    chat::models::Prompt
  end

  wrapper = ->(name) { SearchUI::Wrapper.new(name) }

  describe '#all_system_prompts' do
    it 'returns system prompts sorted by name' do
      prompt_model.create(context: 'system', name: 'zz_b_sys',
                          metadata: { default: false, content: 'B' })
      prompt_model.create(context: 'system', name: 'zz_a_sys',
                          metadata: { default: false, content: 'A' })

      result = chat.all_system_prompts.map(&:value)
      expect(result).to include('zz_a_sys', 'zz_b_sys')
    end

    it 'marks favourited prompts with a heart prefix' do
      prompt_model.create(context: 'system', name: 'zz_fav_sys',
                          metadata: { default: false, content: 'X' })
      chat::models::Favourite.create(context: 'system', name: 'zz_fav_sys')

      entry = chat.all_system_prompts.find { |p| p.value == 'zz_fav_sys' }
      expect(entry.to_s).to include("\u2764\uFE0F")
    end

    it 'does not include prompts from other contexts' do
      prompt_model.create(context: 'prompt', name: 'zz_other_ctx',
                          metadata: { default: false, content: 'O' })

      result = chat.all_system_prompts.map(&:value)
      expect(result).not_to include('zz_other_ctx')
    end
  end

  describe '#model_default_system_prompt' do
    it 'returns the system field from model metadata' do
      chat.instance_variable_set(
        :@model_metadata, OpenStruct.new(system: 'You are helpful.')
      )
      expect(chat.model_default_system_prompt).to eq('You are helpful.')
    end

    it 'returns nil when metadata is not loaded' do
      chat.instance_variable_set(:@model_metadata, nil)
      expect(chat.model_default_system_prompt).to be_nil
    end
  end

  describe '#set_current_system_prompt' do
    it 'sets the prompt on messages and persists to session' do
      expect(chat.messages).to receive(:set_system_prompt).with('zz_my_sys')
      expect(chat.session).to receive(:update)
        .with(current_system_prompt: 'zz_my_sys')

      chat.set_current_system_prompt('zz_my_sys')
    end
  end

  describe '#current_system_prompt_name' do
    it 'delegates to messages#system_name' do
      expect(chat.messages).to receive(:system_name).and_return('zz_active')
      expect(chat.current_system_prompt_name).to eq('zz_active')
    end
  end

  describe '#raw_system_prompt' do
    context 'when using model_default' do
      before do
        chat.instance_variable_set(
          :@model_metadata,
          OpenStruct.new(system: 'Base %{persona} info')
        )
        expect(chat.messages).to receive(:system_name).and_return('model_default')
      end

      it 'returns the model default with placeholders nullified' do
        expect(chat.raw_system_prompt).to eq('Base  info')
      end
    end

    context 'when using a named system prompt' do
      before do
        prompt_model.create(context: 'system', name: 'zz_raw',
                            metadata: { default: false, content: 'Hello %{persona}!' })
        expect(chat.messages).to receive(:system_name).and_return('zz_raw')
      end

      it 'returns the DB content with placeholders nullified' do
        expect(chat.raw_system_prompt).to eq('Hello !')
      end
    end

    it 'handles a missing prompt gracefully' do
      expect(chat.messages).to receive(:system_name).and_return('zz_missing')
      expect(chat.raw_system_prompt).to eq('')
    end
  end

  describe '#current_system_prompt' do
    it 'delegates to messages#system' do
      expect(chat.messages).to receive(:system).and_return('the active prompt')
      expect(chat.current_system_prompt).to eq('the active prompt')
    end
  end

  describe '#setup_system_prompt' do
    context 'when session has a current system prompt' do
      it 'sets it directly without prompting' do
        expect(chat.session).to receive(:current_system_prompt)
          .and_return('zz_session_sys')
        expect(chat).to receive(:set_current_system_prompt).with('zz_session_sys')

        chat.setup_system_prompt
      end
    end

    context 'when session is blank but default prompt exists' do
      it 'falls back to the default prompt name' do
        expect(chat.session).to receive(:current_system_prompt).and_return(nil)
        expect(chat).to receive(:prompt)
          .with(:default, context: 'system').and_return(true)
        expect(chat).to receive(:set_current_system_prompt).with('default')

        chat.setup_system_prompt
      end
    end

    context 'when neither session nor default exist' do
      it 'falls back to model_default' do
        expect(chat.session).to receive(:current_system_prompt).and_return(nil)
        expect(chat).to receive(:prompt)
          .with(:default, context: 'system').and_return(nil)
        expect(chat).to receive(:set_current_system_prompt).with('model_default')

        chat.setup_system_prompt
      end
    end
  end

  describe '#change_system_prompt' do
    let(:fallback) { 'model_default' }

    it 'exits cleanly when user selects [EXIT]' do
      expect(chat).to receive(:all_system_prompts).and_return([wrapper.('x')])
      expect(chat).to receive(:choose_entry).and_return('[EXIT]')

      expect(STDOUT).to receive(:puts).with('Exiting chooser.')
      expect(chat.change_system_prompt(fallback)).to be_nil
    end

    it 'selects the model default' do
      expect(chat).to receive(:all_system_prompts).and_return([wrapper.('x')])
      expect(chat).to receive(:choose_entry).and_return('[MODEL DEFAULT]')
      expect(chat).to receive(:set_current_system_prompt).with('model_default')

      chat.change_system_prompt(fallback)
    end

    it 'uses the fallback default when user cancels (nil)' do
      expect(chat).to receive(:all_system_prompts).and_return([wrapper.('x')])
      expect(chat).to receive(:choose_entry).and_return(nil)
      expect(chat).to receive(:set_current_system_prompt).with(fallback)

      chat.change_system_prompt(fallback)
    end

    it 'uses the selected wrapper value' do
      selected = wrapper.('zz_chosen_sys')
      expect(chat).to receive(:all_system_prompts).and_return([selected])
      expect(chat).to receive(:choose_entry).and_return(selected)
      expect(chat).to receive(:set_current_system_prompt).with('zz_chosen_sys')

      chat.change_system_prompt(fallback)
    end
  end

  describe '#system_prompt_with_favourite' do
    it 'wraps name with favourite heart when favourited' do
      result = chat.system_prompt_with_favourite('zz_my_sys', true)
      expect(result.value).to eq('zz_my_sys')
      expect(result.to_s).to include("\u2764\uFE0F")
    end

    it 'wraps name without heart when not favourited' do
      result = chat.system_prompt_with_favourite('zz_my_sys', false)
      expect(result.value).to eq('zz_my_sys')
      expect(result.to_s).not_to include("\u2764\uFE0F")
    end
  end
end
