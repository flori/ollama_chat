describe OllamaChat::FavouritesManagement do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config).expose
  end

  connect_to_ollama_server

  let :fav_model do
    chat::models::Favourite
  end

  wrapper = ->(name) { SearchUI::Wrapper.new(name) }

  describe '#prefix_favourite' do
    it 'prefixes with a star when favourited' do
      expect(chat.prefix_favourite('llama3.1', true)).to eq '⭐ llama3.1'
    end

    it 'prefixes with a black circle when not favourited' do
      expect(chat.prefix_favourite('llama3.1', false)).to eq '⚫ llama3.1'
    end
  end

  describe '#favourite_all_things' do
    it 'delegates to all_models for type model' do
      things = [ wrapper.('llama3.1') ]
      expect(chat).to receive(:all_models).and_return(things)
      expect(chat.favourite_all_things('model')).to eq things
    end

    it 'delegates to available_personae_names for type persona' do
      things = [ wrapper.('miyu') ]
      expect(chat).to receive(:available_personae_names).and_return(things)
      expect(chat.favourite_all_things('persona')).to eq things
    end

    it 'delegates to all_prompts for other types' do
      things = [ wrapper.('sys_prompt') ]
      expect(chat).to receive(:all_prompts).with(context: 'system').and_return(things)
      expect(chat.favourite_all_things('system')).to eq things
    end
  end

  describe '#choose_favourite' do
    it 'adds and removes favourites in one pass' do
      fav_model.create(context: 'model', name: 'mistral')

      things = [ wrapper.('llama3.1'), wrapper.('mistral') ]
      expect(chat).to receive(:favourite_all_things).and_return(things)
      expect(chat).to receive(:choose_multi).
        and_return([ 'llama3.1', 'mistral' ])

      expect { chat.choose_favourite('model') }.
        to change { fav_model.count }.from(1).to(2)
    end

    it 'aborts without changes when the user presses C-c' do
      fav_model.create(context: 'model', name: 'llama3.1')

      things = [ wrapper.('llama3.1') ]
      expect(chat).to receive(:favourite_all_things).and_return(things)
      expect(chat).to receive(:choose_multi).and_return(nil)

      expect { chat.choose_favourite('model') }.not_to change { fav_model.count }
    end

    it 'does not feedback when nothing changed' do
      fav_model.create(context: 'model', name: 'llama3.1')

      things = [ wrapper.('llama3.1') ]
      expect(chat).to receive(:favourite_all_things).and_return(things)
      expect(chat).to receive(:choose_multi).and_return([ 'llama3.1' ])
      expect(chat).not_to receive(:feedback)

      chat.choose_favourite('model')
    end
  end

  describe '#all_favourited' do
    it 'returns an empty hash when no favourites exist' do
      expect(chat.all_favourited('model')).to eq({})
    end

    it 'returns favourited names mapped to true' do
      fav_model.create(context: 'model', name: 'llama3.1')
      fav_model.create(context: 'model', name: 'mistral')

      expect(chat.all_favourited('model')).to eq(
        'llama3.1' => true,
        'mistral'  => true
      )
    end

    it 'only returns favourites for the given context' do
      fav_model.create(context: 'model', name: 'llama3.1')
      fav_model.create(context: 'prompt', name: 'sys')

      expect(chat.all_favourited('model')).to eq('llama3.1' => true)
      expect(chat.all_favourited('prompt')).to eq('sys' => true)
    end
  end
end
