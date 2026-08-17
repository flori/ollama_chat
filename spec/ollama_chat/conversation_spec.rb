describe OllamaChat::Conversation do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config).expose
  end

  connect_to_ollama_server

  describe '#save_conversation' do
    it 'saves a new conversation (clean: false) and confirms' do
      expect(chat.messages).to receive(:save_conversation)
        .with('./new_chat.jsonl', messages: chat.messages.messages)
        .and_return(true)
      expect(STDOUT).to receive(:puts)
        .with('Saved conversation to "./new_chat.jsonl".')
      chat.save_conversation('./new_chat.jsonl', clean: false)
    end

    it 'saves a new conversation (clean: true) using cleaned messages' do
      expect(chat.messages).to receive(:save_conversation)
        .with('./new_chat.jsonl', messages: chat.messages.clean_messages)
        .and_return(true)
      expect(STDOUT).to receive(:puts)
        .with('Saved conversation to "./new_chat.jsonl".')
      chat.save_conversation('./new_chat.jsonl', clean: true)
    end

    it 'reports failure when save_conversation returns false' do
      expect(chat.messages).to receive(:save_conversation)
        .and_return(false)
      expect(STDERR).to receive(:puts)
        .with('Saving conversation to "./new_chat.jsonl" failed.')
      chat.save_conversation('./new_chat.jsonl', clean: false)
    end

    it 'prompts to overwrite when file already exists and user says yes' do
      tmpfile = File.join(Dir.tmpdir, "conv_#{$$}_existing.jsonl")
      File.write(tmpfile, '{}')

      expect(chat).to receive(:confirm?)
        .with(hash_including(prompt: /already exists, overwrite/))
        .and_return(true)
      expect(chat.messages).to receive(:save_conversation)
        .and_return(true)
      expect(STDOUT).to receive(:puts)
        .with(/Saved conversation to/)
      chat.save_conversation(tmpfile, clean: false)
    ensure
      FileUtils.rm_f(tmpfile)
    end

    it 'aborts when file exists and user says no' do
      tmpfile = File.join(Dir.tmpdir, "conv_#{$$}_existing.jsonl")
      File.write(tmpfile, '{}')

      expect(chat).to receive(:confirm?)
        .and_return(false)
      expect(chat.messages).not_to receive(:save_conversation)
      expect(STDOUT).not_to receive(:puts)
      expect(STDERR).not_to receive(:puts)
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
      expect(STDOUT).to receive(:puts)
        .with('Loaded conversation from "./saved.jsonl".')
      chat.load_conversation('./saved.jsonl')
    end

    it 'loads a conversation without listing when size <= 1' do
      expect(chat.messages).to receive(:load_conversation)
        .and_return(true)
      expect(chat.messages).to receive(:size).and_return(0)
      expect(chat.messages).not_to receive(:list_conversation)
      expect(STDOUT).to receive(:puts)
        .with('Loaded conversation from "./saved.jsonl".')
      chat.load_conversation('./saved.jsonl')
    end

    it 'reports failure but still lists when size > 1' do
      expect(chat.messages).to receive(:load_conversation)
        .and_return(false)
      expect(chat.messages).to receive(:size).and_return(3)
      expect(chat.messages).to receive(:list_conversation).with(2)
      expect(STDERR).to receive(:puts)
        .with('Loading conversation from "./saved.jsonl" failed.')
      chat.load_conversation('./saved.jsonl')
    end

    it 'reports failure without listing when size <= 1' do
      expect(chat.messages).to receive(:load_conversation)
        .and_return(false)
      expect(chat.messages).to receive(:size).and_return(0)
      expect(chat.messages).not_to receive(:list_conversation)
      expect(STDERR).to receive(:puts)
        .with('Loading conversation from "./saved.jsonl" failed.')
      chat.load_conversation('./saved.jsonl')
    end
  end
end
