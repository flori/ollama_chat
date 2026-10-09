describe OllamaChat::Conversation do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config).expose
  end

  connect_to_ollama_server

  describe '#save_conversation' do
    it 'saves a new conversation (clean: false) and confirms' do
      expect(chat.messages).to receive(:save_conversation)
        .with(Pathname.new('./new_chat.jsonl'), messages: chat.messages.messages)
        .and_return(true)
      expect(chat).to receive(:feedback)
        .with('Saved conversation to "./new_chat.jsonl".', type: :info)
      chat.save_conversation('./new_chat.jsonl', clean: false)
    end

    it 'saves a new conversation (clean: true) using cleaned messages' do
      expect(chat.messages).to receive(:save_conversation)
        .with(Pathname.new('./new_chat.jsonl'), messages: chat.messages.clean_messages)
        .and_return(true)
      expect(chat).to receive(:feedback)
        .with('Saved cleaned conversation to "./new_chat.jsonl".', type: :info)
      chat.save_conversation('./new_chat.jsonl', clean: true)
    end

    it 'reports failure when save_conversation returns false' do
      expect(chat.messages).to receive(:save_conversation)
        .and_return(false)
      expect(chat).to receive(:feedback)
        .with('Saving conversation to "./new_chat.jsonl" failed.', type: :warn)
      chat.save_conversation('./new_chat.jsonl', clean: false)
    end

    it 'prompts to overwrite when file already exists and user says yes' do
      tmpfile = asset_tmp_path('tmp/conv_existing.jsonl').to_s
      File.write(tmpfile, '{}')

      expect(chat).to receive(:confirm?)
        .with(hash_including(prompt: /already exists, overwrite/))
        .and_return(true)
      expect(chat.messages).to receive(:save_conversation)
        .and_return(true)
      expect(chat).to receive(:feedback)
        .with(a_string_including('Saved conversation to'), type: :info)
      chat.save_conversation(tmpfile, clean: false)
    ensure
      FileUtils.rm_f(tmpfile)
    end

    it 'aborts when file exists and user says no' do
      tmpfile = asset_tmp_path('tmp/conv_existing.jsonl').to_s
      File.write(tmpfile, '{}')

      expect(chat).to receive(:confirm?)
        .and_return(false)
      expect(chat.messages).not_to receive(:save_conversation)
      expect(chat).to receive(:feedback).with('File not written!', type: :warn)
      chat.save_conversation(tmpfile, clean: false)
    ensure
      FileUtils.rm_f(tmpfile)
    end
  end

  describe '#load_conversation' do
    it 'loads a conversation and lists messages when size > 1' do
      expect(chat.messages).to receive(:load_conversation)
        .and_return(true)
      expect(chat.messages).to receive(:size).and_return(5)
      expect(chat.messages).to receive(:list_conversation).with(2)
      expect(chat).to receive(:feedback)
        .with('Loaded conversation from "./saved.jsonl".', type: :info)
      chat.load_conversation('./saved.jsonl')
    end

    it 'loads a conversation without listing when size <= 1' do
      expect(chat.messages).to receive(:load_conversation)
        .and_return(true)
      expect(chat.messages).to receive(:size).and_return(0)
      expect(chat.messages).not_to receive(:list_conversation)
      expect(chat).to receive(:feedback)
        .with('Loaded conversation from "./saved.jsonl".', type: :info)
      chat.load_conversation('./saved.jsonl')
    end

    it 'reports failure but still lists when size > 1' do
      expect(chat.messages).to receive(:load_conversation)
        .and_return(false)
      expect(chat.messages).to receive(:size).and_return(3)
      expect(chat.messages).to receive(:list_conversation).with(2)
      expect(chat).to receive(:feedback)
        .with('Loading conversation from "./saved.jsonl" failed.', type: :warn)
      chat.load_conversation('./saved.jsonl')
    end

    it 'reports failure without listing when size <= 1' do
      expect(chat.messages).to receive(:load_conversation)
        .and_return(false)
      expect(chat.messages).to receive(:size).and_return(0)
      expect(chat.messages).not_to receive(:list_conversation)
      expect(chat).to receive(:feedback)
        .with('Loading conversation from "./saved.jsonl" failed.', type: :warn)
      chat.load_conversation('./saved.jsonl')
    end
  end

  describe '#conversation_clean' do
    it 'cancels when nothing is selected' do
      expect(chat).to receive(:choose_entry).and_return('[DONE]')
      expect(chat).to receive(:feedback)
        .with('Cancelled, nothing selected.', type: :cancel)
      chat.conversation_clean
    end

    it 'denies when user says no at the confirm gate' do
      expect(chat).to receive(:choose_entry).and_return('tools', '[DONE]')
      expect(chat).to receive(:confirm?).and_return(false)
      expect(chat).to receive(:feedback).with('Denied.', type: :denied)
      chat.conversation_clean
    end

    it 'cleans field-only options (tools, images, thinking)' do
      expect(chat).to receive(:choose_entry)
        .and_return('tools', 'images', 'thinking', '[DONE]')
      expect(chat).to receive(:confirm?).and_return(true)
      expect(chat.messages).to receive(:clean_messages!)
        .with(what: %i[ tools images thinking ])
      expect(chat.messages).not_to receive(:clear)
      expect(chat).not_to receive(:clear_history)
      expect(chat.links).not_to receive(:clear)
      expect(chat).to receive(:session_sync)
      expect(chat).to receive(:feedback)
        .with(a_string_including('Cleaned'), type: :info)
      chat.conversation_clean
    end

    it 'clears messages and cleans fields when both are selected' do
      expect(chat).to receive(:choose_entry)
        .and_return('messages', 'tools', '[DONE]')
      expect(chat).to receive(:confirm?).and_return(true)
      expect(chat.messages).to receive(:clear)
      expect(chat.messages).to receive(:clean_messages!).with(what: %i[ tools ])
      expect(chat).not_to receive(:clear_history)
      expect(chat.links).not_to receive(:clear)
      expect(chat).to receive(:session_sync)
      expect(chat).to receive(:feedback)
        .with(a_string_including('Cleaned'), type: :info)
      chat.conversation_clean
    end

    it 'clears links when selected' do
      expect(chat).to receive(:choose_entry).and_return('links', '[DONE]')
      expect(chat).to receive(:confirm?).and_return(true)
      expect(chat.links).to receive(:clear)
      expect(chat.messages).not_to receive(:clean_messages!)
      expect(chat.messages).not_to receive(:clear)
      expect(chat).not_to receive(:clear_history)
      expect(chat).to receive(:session_sync)
      expect(chat).to receive(:feedback)
        .with(a_string_including('Cleaned'), type: :info)
      chat.conversation_clean
    end

    it 'clears history when selected' do
      expect(chat).to receive(:choose_entry).and_return('history', '[DONE]')
      expect(chat).to receive(:confirm?).and_return(true)
      expect(chat).to receive(:clear_history)
      expect(chat.messages).not_to receive(:clean_messages!)
      expect(chat.messages).not_to receive(:clear)
      expect(chat.links).not_to receive(:clear)
      expect(chat).to receive(:session_sync)
      expect(chat).to receive(:feedback)
        .with(a_string_including('Cleaned'), type: :info)
      chat.conversation_clean
    end
  end
end
