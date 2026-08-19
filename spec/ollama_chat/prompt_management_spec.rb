describe OllamaChat::PromptManagement do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config).expose
  end

  connect_to_ollama_server

  let :prompt_model do
    chat::models::Prompt
  end

  wrapper = ->(name) { SearchUI::Wrapper.new(name) }

  describe '#all_prompts' do
    it 'returns prompts sorted by name' do
      prompt_model.create(context: 'prompt', name: 'zz_b_prompt', metadata: { default: false, content: 'B' })
      prompt_model.create(context: 'prompt', name: 'zz_a_prompt', metadata: { default: false, content: 'A' })

      result = chat.all_prompts.map(&:value)
      expect(result).to include('zz_a_prompt', 'zz_b_prompt')
      expect(result).to eq(result.sort)
    end

    it 'marks favourited prompts with a heart prefix' do
      prompt_model.create(context: 'prompt', name: 'zz_my_prompt', metadata: { default: false, content: 'X' })
      chat::models::Favourite.create(context: 'prompt', name: 'zz_my_prompt')

      entry = chat.all_prompts.find { |p| p.value == 'zz_my_prompt' }
      expect(entry.to_s).to include("\u2764\uFE0F")
    end

    it 'filters by default: true' do
      prompt_model.create(context: 'prompt', name: 'zz_def1', metadata: { default: true, content: 'D' })
      prompt_model.create(context: 'prompt', name: 'zz_nondef', metadata: { default: false, content: 'N' })

      result = chat.all_prompts(default: true).map(&:value)
      expect(result).to include('zz_def1')
      expect(result).not_to include('zz_nondef')
    end

    it 'filters by context' do
      prompt_model.create(context: 'prompt', name: 'zz_p1', metadata: { default: false, content: 'P' })
      prompt_model.create(context: 'system', name: 'zz_s1', metadata: { default: false, content: 'S' })

      result = chat.all_prompts(context: 'system').map(&:value)
      expect(result).to include('zz_s1')
      expect(result).not_to include('zz_p1')
    end
  end

  describe '#choose_prompt_context' do
    it 'returns the selected context' do
      prompt_model.create(context: 'prompt', name: 'p', metadata: { default: false, content: 'x' })
      prompt_model.create(context: 'system', name: 's', metadata: { default: false, content: 'y' })

      expect(chat).to receive(:choose_entry).and_return('system')
      expect(chat.choose_prompt_context).to eq('system')
    end

    it 'returns nil when user selects [EXIT]' do
      expect(chat).to receive(:choose_entry).and_return('[EXIT]')
      expect(STDOUT).to receive(:puts).with('Exiting chooser.')
      expect(chat.choose_prompt_context).to be_nil
    end

    it 'returns nil when user cancels' do
      expect(chat).to receive(:choose_entry).and_return(nil)
      expect(STDOUT).to receive(:puts).with('Exiting chooser.')
      expect(chat.choose_prompt_context).to be_nil
    end
  end

  describe '#choose_prompt' do
    it 'returns the selected prompt model' do
      prompt_model.create(context: 'prompt', name: 'target', metadata: { default: false, content: 'T' })
      things = [wrapper.('target')]
      expect(chat).to receive(:all_prompts).and_return(things)
      expect(chat).to receive(:choose_entry).and_return(things[0])

      result = chat.choose_prompt
      expect(result).to be_a(prompt_model)
      expect(result.name).to eq('target')
    end

    it 'returns nil when user selects [EXIT]' do
      expect(chat).to receive(:all_prompts).and_return([wrapper.('x')])
      expect(chat).to receive(:choose_entry).and_return('[EXIT]')
      expect(STDOUT).to receive(:puts).with('Exiting chooser.')
      expect(chat.choose_prompt).to be_nil
    end

    it 'returns nil when user cancels' do
      expect(chat).to receive(:all_prompts).and_return([wrapper.('x')])
      expect(chat).to receive(:choose_entry).and_return(nil)
      expect(STDOUT).to receive(:puts).with('Exiting chooser.')
      expect(chat.choose_prompt).to be_nil
    end
  end

  describe '#info_prompt' do
    it 'displays prompt info via pager' do
      prompt_model.create(context: 'prompt', name: 'inspect_me',
                          metadata: { default: false, content: 'Content here' })
      expect(chat).to receive(:choose_prompt).and_return(chat.prompt('inspect_me'))
      expect(chat).to receive(:use_pager) { |&blk| blk.call(StringIO.new) }

      expect(chat.info_prompt).to eq(chat)
    end

    it 'does not call use_pager when no prompt selected' do
      expect(chat).to receive(:choose_prompt).and_return(nil)
      expect(chat).not_to receive(:use_pager)
      expect(chat.info_prompt).to eq(chat)
    end
  end

  describe '#add_new_prompt' do
    it 'creates a new prompt' do
      expect(chat).to receive(:switch_history).with(:prompt).and_yield
      expect(chat).to receive(:determine_valid_new_name_for_prompt).and_return('new_p')
      expect(chat).to receive(:choose_entry).and_return('[EMPTY/MANUAL]')
      expect(chat).to receive(:edit_text).and_return('new content')
      expect(chat).to receive(:store_prompt).with('new_p', 'new content', context: 'prompt')

      expect(chat.add_new_prompt).to eq(chat)
    end

    it 'returns nil when name determination fails' do
      expect(chat).to receive(:switch_history).with(:prompt).and_yield
      expect(chat).to receive(:determine_valid_new_name_for_prompt).and_return(nil)
      expect(chat.add_new_prompt).to be_nil
    end
  end

  describe '#choose_and_delete_prompt' do
    it 'deletes the selected prompt after confirmation' do
      p = prompt_model.create(context: 'prompt', name: 'doomed',
                              metadata: { default: false, content: 'D' })
      expect(chat).to receive(:choose_prompt).and_return(p)
      expect(chat).to receive(:confirm?).and_return(true)

      expect { chat.choose_and_delete_prompt }.to change { prompt_model.count }.by(-1)
    end

    it 'does not delete when user declines' do
      prompt_model.create(context: 'prompt', name: 'safe', metadata: { default: false, content: 'S' })
      expect(chat).to receive(:choose_prompt).and_return(chat.prompt('safe'))
      expect(chat).to receive(:confirm?).and_return(false)

      expect { chat.choose_and_delete_prompt }.not_to change { prompt_model.count }
    end

    it 'returns nil when no prompt selected' do
      expect(chat).to receive(:choose_prompt).and_return(nil)
      expect(chat.choose_and_delete_prompt).to be_nil
    end
  end

  describe '#choose_and_edit_prompt' do
    it 'edits and saves the prompt content' do
      p = prompt_model.create(context: 'prompt', name: 'editable',
                              metadata: { default: false, content: 'old' })
      expect(chat).to receive(:choose_prompt).and_return(p)
      expect(chat).to receive(:edit_text).and_return('updated content')

      expect(chat.choose_and_edit_prompt).to eq(chat)
      expect(p.reload.metadata['content']).to eq('updated content')
    end

    it 'returns nil when no prompt selected' do
      expect(chat).to receive(:choose_prompt).and_return(nil)
      expect(chat.choose_and_edit_prompt).to be_nil
    end
  end

  describe '#duplicate_prompt' do
    it 'creates a duplicate with a new name' do
      original = prompt_model.create(context: 'prompt', name: 'orig',
                                     metadata: { default: true, content: 'O' })
      expect(chat).to receive(:switch_history).with(:prompt).and_yield
      expect(chat).to receive(:choose_prompt).and_return(original)
      expect(chat).to receive(:ask?).and_return('copy1')
      expect(chat).to receive(:prompt).with('copy1', context: 'prompt').and_return(nil)

      expect { chat.duplicate_prompt }.to change { prompt_model.count }.by(1)
      dup = prompt_model.where(name: 'copy1').first
      expect(dup.metadata['content']).to eq('O')
      expect(dup.metadata['default']).to be false
    end

    it 're-prompts if name already exists' do
      prompt_model.create(context: 'prompt', name: 'orig', metadata: { default: false, content: 'O' })
      prompt_model.create(context: 'prompt', name: 'taken', metadata: { default: false, content: 'T' })
      expect(chat).to receive(:switch_history).with(:prompt).and_yield
      expect(chat).to receive(:choose_prompt).and_return(chat.prompt('orig'))
      expect(chat).to receive(:ask?).and_return('taken', 'new_name')
      expect(chat).to receive(:prompt).with('taken', context: 'prompt')
        .and_return(prompt_model.where(name: 'taken').first)
      expect(chat).to receive(:prompt).with('new_name', context: 'prompt')
        .and_return(nil)

      expect { chat.duplicate_prompt }.to change { prompt_model.count }.by(1)
      expect(prompt_model.where(name: 'new_name').first).not_to be_nil
    end

    it 'cancels when user provides nil name' do
      prompt_model.create(context: 'prompt', name: 'orig', metadata: { default: false, content: 'O' })
      expect(chat).to receive(:switch_history).with(:prompt).and_yield
      expect(chat).to receive(:choose_prompt).and_return(chat.prompt('orig'))
      expect(chat).to receive(:ask?).and_return(nil)

      expect { chat.duplicate_prompt }.not_to change { prompt_model.count }
    end
  end

  describe '#rename_prompt' do
    it 'renames the selected prompt' do
      p = prompt_model.create(context: 'prompt', name: 'old_name',
                              metadata: { default: false, content: 'X' })
      expect(chat).to receive(:switch_history).with(:prompt).and_yield
      expect(chat).to receive(:choose_prompt).and_return(p)
      expect(chat).to receive(:ask?).and_return('new_name')
      expect(chat).to receive(:prompt).with('new_name', context: 'prompt').and_return(nil)

      expect { chat.rename_prompt }.to change { p.reload.name }.from('old_name').to('new_name')
    end

    it 're-prompts if name is the current name' do
      p = prompt_model.create(context: 'prompt', name: 'same',
                              metadata: { default: false, content: 'X' })
      expect(chat).to receive(:switch_history).with(:prompt).and_yield
      expect(chat).to receive(:choose_prompt).and_return(p)
      expect(chat).to receive(:ask?).and_return('same', 'different')
      expect(chat).to receive(:prompt).with('different', context: 'prompt').and_return(nil)

      expect { chat.rename_prompt }.to change { p.reload.name }.to('different')
    end

    it 're-prompts if name already exists' do
      prompt_model.create(context: 'prompt', name: 'orig', metadata: { default: false, content: 'X' })
      prompt_model.create(context: 'prompt', name: 'taken', metadata: { default: false, content: 'T' })
      expect(chat).to receive(:switch_history).with(:prompt).and_yield
      expect(chat).to receive(:choose_prompt).and_return(chat.prompt('orig'))
      expect(chat).to receive(:ask?).and_return('taken', 'fresh')
      expect(chat).to receive(:prompt).with('taken', context: 'prompt')
        .and_return(prompt_model.where(name: 'taken').first)
      expect(chat).to receive(:prompt).with('fresh', context: 'prompt')
        .and_return(nil)

      expect { chat.rename_prompt }.to change { prompt_model.where(name: 'fresh').count }.by(1)
    end

    it 'cancels when user provides nil name' do
      p = prompt_model.create(context: 'prompt', name: 'cancel_me',
                              metadata: { default: false, content: 'X' })
      expect(chat).to receive(:switch_history).with(:prompt).and_yield
      expect(chat).to receive(:choose_prompt).and_return(p)
      expect(chat).to receive(:ask?).and_return(nil)

      expect { chat.rename_prompt }.not_to change { p.reload.name }
    end
  end

  describe '#import_prompt' do
    it 'imports a prompt from an existing file' do
      file = asset('prompt.txt')
      expect(chat).to receive(:determine_valid_new_name_for_prompt)
        .with('to import', context: 'prompt').and_return('imported')
      expect(chat).to receive(:store_prompt)

      expect(chat.import_prompt(file)).to eq(chat)
    end

    it 'prompts for file selection when no filename given' do
      expect(chat).to receive(:choose_filename).and_return(Pathname.new(asset('prompt.txt')))
      expect(chat).to receive(:determine_valid_new_name_for_prompt).and_return('imported')
      expect(chat).to receive(:store_prompt)

      expect(chat.import_prompt(nil)).to eq(chat)
    end

    it 'cancels when no file selected' do
      expect(chat).to receive(:choose_filename).and_return(nil)
      expect(STDOUT).to receive(:puts).with('Cancelled.')
      expect(chat.import_prompt(nil)).to be_nil
    end

    it 'returns nil when name determination fails' do
      expect(chat).to receive(:choose_filename).and_return(Pathname.new(asset('prompt.txt')))
      expect(chat).to receive(:determine_valid_new_name_for_prompt).and_return(nil)
      expect(chat.import_prompt(nil)).to be_nil
    end
  end

  describe '#export_prompt' do
    it 'exports the selected prompt to a file' do
      prompt_model.create(context: 'prompt', name: 'exportable',
                          metadata: { default: false, content: 'Export me' })
      out = Pathname.pwd.join('tmp', 'export_out.txt')
      expect(chat).to receive(:choose_prompt).and_return(chat.prompt('exportable'))
      expect(chat).to receive(:determine_valid_output_filename).and_return(out)

      expect(chat.export_prompt).to eq(chat)
      expect(out.read).to include('Export me')
      out.delete
    end

    it 'returns nil when no prompt selected' do
      expect(chat).to receive(:choose_prompt).and_return(nil)
      expect(chat.export_prompt).to be_nil
    end

    it 'returns nil when filename is not provided' do
      prompt_model.create(context: 'prompt', name: 'x', metadata: { default: false, content: 'x' })
      expect(chat).to receive(:choose_prompt).and_return(chat.prompt('x'))
      expect(chat).to receive(:determine_valid_output_filename).and_return(nil)
      expect(chat.export_prompt).to be_nil
    end
  end

  describe '#prepare_conversation_history' do
    it 'aggregates messages as sender: content pairs' do
      chat.messages << OllamaChat::Message.new(role: 'user', content: 'hello')
      chat.messages << OllamaChat::Message.new(role: 'assistant', content: 'world')
      expect(chat).to receive(:sender_name_displayed).and_return('User', 'Miyu')

      history = chat.prepare_conversation_history
      expect(history).to include('hello')
      expect(history).to include('world')
    end

    it 'skips messages without content' do
      chat.messages << OllamaChat::Message.new(role: 'user', content: '')
      chat.messages << OllamaChat::Message.new(role: 'user', content: 'visible')
      expect(chat).to receive(:sender_name_displayed).and_return('User')

      history = chat.prepare_conversation_history
      expect(history).to include('visible')
    end
  end

  describe '#suggest_prompts' do
    it 'generates suggestions using a template' do
      prompt_model.create(context: 'suggest', name: 'zz_suggest_me',
                          metadata: { default: false, content: 'Suggest code improvements' })

      chat.messages << OllamaChat::Message.new(role: 'user', content: 'help me')
      expect(chat).to receive(:sender_name_displayed).and_return('User')
      expect(chat).to receive(:choose_prompt)
        .and_return(chat.prompt('zz_suggest_me', context: 'suggest'))
      expect(chat).to receive(:generate).and_return('Suggestion 1\nSuggestion 2')
      expect(chat).to receive(:edit_text).and_return('Final suggestion')

      expect(chat.suggest_prompts).to eq('Final suggestion')
    end

    it 'expects custom instruction when edit: true' do
      chat.messages << OllamaChat::Message.new(role: 'user', content: 'hi')
      expect(chat).to receive(:sender_name_displayed).and_return('User')
      expect(chat).to receive(:edit_text).twice
        .and_return('My custom instruction')
        .and_return('Refined')
      expect(chat).to receive(:generate).and_return('Generated stuff')

      expect(chat.suggest_prompts(edit: true)).to eq('Refined')
    end

    it 'returns nil when generation fails' do
      prompt_model.create(context: 'suggest', name: 'x',
                          metadata: { default: false, content: 'inst' })
      chat.messages << OllamaChat::Message.new(role: 'user', content: 'x')
      expect(chat).to receive(:sender_name_displayed).and_return('User')
      expect(chat).to receive(:choose_prompt)
        .and_return(chat.prompt('x', context: 'suggest'))
      expect(chat).to receive(:generate).and_return('')

      expect(chat.suggest_prompts).to be_nil
    end
  end

  describe '#list_prompts' do
    it 'lists all prompts without raising errors' do
      prompt_model.create(context: 'prompt', name: 'def_p',
                          metadata: { default: true, content: 'Default content' })
      prompt_model.create(context: 'prompt', name: 'user_p',
                          metadata: { default: false, content: 'User content' })

      expect(STDOUT).to receive(:print).at_least(:once)
      expect(STDOUT).to receive(:puts).at_least(:once)
      expect { chat.list_prompts }.not_to raise_error
    end

    it 'filters by context' do
      prompt_model.create(context: 'prompt', name: 'a', metadata: { default: false, content: 'A' })
      prompt_model.create(context: 'system', name: 'b', metadata: { default: false, content: 'B' })

      expect(STDOUT).to receive(:print).at_least(:once)
      expect(STDOUT).to receive(:puts).at_least(:once)
      expect { chat.list_prompts(context: 'system') }.not_to raise_error
    end
  end

  describe '#reset_prompt_to_default' do
    it 'resets prompt content from config defaults' do
      prompt_model.create(context: 'prompt', name: 'reset_me',
                          metadata: { default: true, content: 'modified' })
      expect(chat.config.prompts).to receive(:prompt)
        .and_return('reset_me' => 'original content')

      expect(chat.reset_prompt_to_default('reset_me')).to be true
      expect(chat.prompt('reset_me').reload.metadata['content']).to eq('original content')
    end

    it 'returns nil when no default found in config' do
      expect(chat.config.prompts).to receive(:prompt).and_return({})
      expect(chat.reset_prompt_to_default('nonexistent')).to be_nil
    end
  end

  describe '#prompt_with_favourite' do
    it 'wraps name with favourite heart when favourited' do
      result = chat.prompt_with_favourite('my_prompt', true)
      expect(result.value).to eq('my_prompt')
      expect(result.to_s).to include("\u2764\uFE0F")
    end

    it 'wraps name without heart when not favourited' do
      result = chat.prompt_with_favourite('my_prompt', false)
      expect(result.value).to eq('my_prompt')
      expect(result.to_s).not_to include("\u2764\uFE0F")
    end
  end

  describe '#determine_valid_new_name_for_prompt' do
    it 'returns the name immediately if unique' do
      expect(chat).to receive(:switch_history).with(:prompt).and_yield
      expect(chat).to receive(:ask?).and_return('unique_name')
      expect(chat).to receive(:prompt).and_return(nil)

      expect(chat.determine_valid_new_name_for_prompt('to add')).to eq('unique_name')
    end

    it 're-prompts if the name already exists' do
      prompt_model.create(context: 'prompt', name: 'taken',
                          metadata: { default: false, content: 'T' })
      expect(chat).to receive(:switch_history).with(:prompt).and_yield
      expect(chat).to receive(:ask?).and_return('taken', 'fresh')
      expect(chat).to receive(:prompt).with('taken', context: 'prompt')
        .and_return(prompt_model.where(name: 'taken').first)
      expect(chat).to receive(:prompt).with('fresh', context: 'prompt')
        .and_return(nil)

      expect(chat.determine_valid_new_name_for_prompt('to add')).to eq('fresh')
    end

    it 'returns nil when user cancels' do
      expect(chat).to receive(:switch_history).with(:prompt).and_yield
      expect(chat).to receive(:ask?).and_return(nil)
      expect(STDOUT).to receive(:puts).with('Cancelled.')

      expect(chat.determine_valid_new_name_for_prompt('to add')).to be_nil
    end
  end

  describe '#prompt_sync' do
    it 'reports all in sync when no drift or orphans' do
      expect(chat.config.prompts).to receive(:[]).with('prompt')
        .and_return({})
      expect(chat).to receive(:each_prompt)
        .with(context: 'prompt', default: true).and_return([])

      expect(STDOUT).to receive(:puts).with(/in sync/)
      expect(chat.prompt_sync).to eq(chat)
    end

    it 'detects drifted prompts and calls show_prompt_diff' do
      p = prompt_model.create(context: 'prompt', name: 'zz_drifted',
                              metadata: { default: true, content: 'local' })
      expect(chat.config.prompts).to receive(:[]).with('prompt')
        .and_return('zz_drifted' => 'shipped')
      expect(chat).to receive(:each_prompt)
        .with(context: 'prompt', default: true).and_return([p])

      expect(chat).to receive(:confirm?)
        .with(hash_including(prompt: /Press any key/)).twice.and_return(true)
      expect(chat).to receive(:show_prompt_diff)
        .with(p, 'shipped', context: 'prompt')
      expect(chat.prompt_sync).to eq(chat)
    end

    it 'detects orphaned prompts and cleans up on confirm' do
      p = prompt_model.create(context: 'prompt', name: 'zz_orphan',
                              metadata: { default: true, content: 'x' })
      expect(chat.config.prompts).to receive(:[]).with('prompt')
        .and_return({})
      expect(chat).to receive(:each_prompt)
        .with(context: 'prompt', default: true).and_return([p])

      expect(chat).to receive(:confirm?)
        .with(hash_including(prompt: /Press any key/)).twice.and_return(true)
      expect(chat).to receive(:confirm?)
        .with(hash_including(prompt: /Remove/)).and_return(true)
      expect { chat.prompt_sync }.to change { prompt_model.count }.by(-1)
    end

    it 'keeps orphans when user declines cleanup' do
      p = prompt_model.create(context: 'prompt', name: 'zz_orphan',
                              metadata: { default: true, content: 'x' })
      expect(chat.config.prompts).to receive(:[]).with('prompt')
        .and_return({})
      expect(chat).to receive(:each_prompt)
        .with(context: 'prompt', default: true).and_return([p])

      expect(chat).to receive(:confirm?)
        .with(hash_including(prompt: /Press any key/)).twice.and_return(true)
      expect(chat).to receive(:confirm?)
        .with(hash_including(prompt: /Remove/)).and_return(false)
      expect { chat.prompt_sync }.not_to change { prompt_model.count }
    end

    it 'handles both drifted and orphaned prompts' do
      drifted = prompt_model.create(context: 'prompt', name: 'zz_drifted',
                                    metadata: { default: true, content: 'local' })
      orphan  = prompt_model.create(context: 'prompt', name: 'zz_orphan',
                                    metadata: { default: true, content: 'x' })
      expect(chat.config.prompts).to receive(:[]).with('prompt')
        .and_return('zz_drifted' => 'shipped')
      expect(chat).to receive(:each_prompt)
        .with(context: 'prompt', default: true).and_return([drifted, orphan])

      expect(chat).to receive(:confirm?)
        .with(hash_including(prompt: /Press any key/)).twice.and_return(true)
      expect(chat).to receive(:show_prompt_diff)
        .with(drifted, 'shipped', context: 'prompt')
      expect(chat).to receive(:confirm?)
        .with(hash_including(prompt: /Remove/)).and_return(true)

      expect { chat.prompt_sync }
        .to change { prompt_model.where(name: 'zz_orphan').count }
        .from(1).to(0)
    end
  end

  describe '#show_prompt_diff' do
    it 'displays diff and skips resolution when declined' do
      p = prompt_model.create(context: 'prompt', name: 'zz_diff_me',
                              metadata: { default: true, content: 'local' })

      expect(chat).to receive(:confirm?).and_return(false)
      expect { chat.show_prompt_diff(p, 'shipped', context: 'prompt') }
        .not_to raise_error
    end

    it 'updates prompt when resolved content differs' do
      p = prompt_model.create(context: 'prompt', name: 'zz_resolve',
                              metadata: { default: true, content: 'before' })

      expect(chat).to receive(:confirm?).and_return(true)
      expect(OC).to receive(:DIFF_TOOL?).and_return(%w[vimdiff])
      # Simulate vimdiff editing file_a by wrapping system to write to it
      expect(chat).to receive(:system) do |*args|
        file_a = args[-2]
        File.write(file_a, 'after resolution')
        true
      end

      expect(chat).to receive(:write_prompt)
        .with('zz_resolve', 'after resolution', context: 'prompt')

      expect { chat.show_prompt_diff(p, 'default', context: 'prompt') }
        .not_to raise_error
    end
  end
end
