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
    it 'prefixes with a red heart when favourited' do
      expect(chat.prefix_favourite('llama3.1', true)).to eq "\u2764\uFE0F llama3.1"
    end

    it 'prefixes with a grey heart when not favourited' do
      expect(chat.prefix_favourite('llama3.1', false)).to eq "🩶 llama3.1"
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

  describe '#add_favourite' do
    it 'adds a new favourite and then exits' do
      things = [ wrapper.('llama3.1'), wrapper.('mistral') ]
      expect(chat).to receive(:favourite_all_things).and_return(things)
      expect(chat).to receive(:choose_entry).and_return(things[0], '[EXIT]')

      expect { chat.add_favourite('model') }.to change { fav_model.count }.from(0).to(1)

      fav = fav_model.first
      expect(fav.context).to eq 'model'
      expect(fav.name).to eq 'llama3.1'
    end

    it 'reports when all items are already favourited' do
      fav_model.create(context: 'model', name: 'llama3.1')

      things = [ wrapper.('llama3.1') ]
      expect(chat).to receive(:favourite_all_things).and_return(things)

      expect(STDOUT).to receive(:puts).with('All items are already favourited.')
      chat.add_favourite('model')
    end

    it 'exits without adding when user selects [EXIT]' do
      things = [ wrapper.('llama3.1') ]
      expect(chat).to receive(:favourite_all_things).and_return(things)
      expect(chat).to receive(:choose_entry).and_return('[EXIT]')

      expect(STDOUT).to receive(:puts).with('Cancelled.')
      expect { chat.add_favourite('model') }.not_to change { fav_model.count }
    end

    it 'exits without adding when user cancels (nil)' do
      things = [ wrapper.('llama3.1') ]
      expect(chat).to receive(:favourite_all_things).and_return(things)
      expect(chat).to receive(:choose_entry).and_return(nil)

      expect(STDOUT).to receive(:puts).with('Cancelled.')
      expect { chat.add_favourite('model') }.not_to change { fav_model.count }
    end
  end

  describe '#delete_favourite' do
    it 'removes a favourite and then exits' do
      fav_model.create(context: 'model', name: 'llama3.1')

      things = [ wrapper.('llama3.1') ]
      expect(chat).to receive(:favourite_all_things).and_return(things)
      expect(chat).to receive(:choose_entry).and_return(things[0], '[EXIT]')

      expect { chat.delete_favourite('model') }.to change { fav_model.count }.from(1).to(0)
    end

    it 'exits without deleting when user selects [EXIT]' do
      fav_model.create(context: 'model', name: 'llama3.1')

      things = [ wrapper.('llama3.1') ]
      expect(chat).to receive(:favourite_all_things).and_return(things)
      expect(chat).to receive(:choose_entry).and_return('[EXIT]')

      expect(STDOUT).to receive(:puts).with('Cancelled.')
      expect { chat.delete_favourite('model') }.not_to change { fav_model.count }
    end

    it 'exits without deleting when user cancels (nil)' do
      fav_model.create(context: 'model', name: 'llama3.1')

      things = [ wrapper.('llama3.1') ]
      expect(chat).to receive(:favourite_all_things).and_return(things)
      expect(chat).to receive(:choose_entry).and_return(nil)

      expect(STDOUT).to receive(:puts).with('Cancelled.')
      expect { chat.delete_favourite('model') }.not_to change { fav_model.count }
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
