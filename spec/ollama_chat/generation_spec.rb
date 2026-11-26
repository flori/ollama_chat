# frozen_string_literal: true

describe OllamaChat::Generation do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config).expose
  end

  connect_to_ollama_server

  describe '#generate' do
    it 'sends system + prompt to call_ollama_chat' do
      allow(chat).to receive(:call_ollama_chat).
        and_return(OpenStruct.new(message: OpenStruct.new(content: 'hi')))

      result = chat.generate(prompt: 'hello')
      expect(result).to eq('hi')
    end

    it 'forwards the truncate: kwarg without crashing' do
      allow(chat).to receive(:current_context_length).and_return(10)
      allow(chat).to receive(:call_ollama_chat).
        and_return(OpenStruct.new(message: OpenStruct.new(content: 'x')))
      allow(chat).to receive(:feedback)

      chat.generate(prompt: 'a' * 1000, truncate: :trailing)
    end

    it 'logs a warning when content is empty' do
      allow(chat).to receive(:call_ollama_chat).
        and_return(OpenStruct.new(message: OpenStruct.new(content: '')))

      expect(chat).to receive(:log).with(
        :warn,
        a_string_including('empty content'),
        anything
      )

      chat.generate(prompt: 'test')
    end
  end

  describe '#guard_context_length' do
    let(:system) { 'You are helpful.' }

    context 'when current_context_length is nil' do
      before do
        allow(chat).to receive(:current_context_length).and_return(nil)
      end

      it 'returns the prompt unchanged' do
        result = chat.guard_context_length('some prompt', system,
                                           truncate: :leading)
        expect(result).to eq('some prompt')
      end
    end

    context 'when prompt is under budget' do
      before do
        allow(chat).to receive(:current_context_length).and_return(8192)
      end

      it 'returns the prompt unchanged' do
        result = chat.guard_context_length('short prompt', system,
                                           truncate: :leading)
        expect(result).to eq('short prompt')
      end

      it 'does not call feedback' do
        expect(chat).not_to receive(:feedback)
        chat.guard_context_length('short prompt', system,
                                  truncate: :leading)
      end
    end

    context 'when prompt exceeds budget' do
      before do
        allow(chat).to receive(:current_context_length).and_return(64)
      end

      let(:long_prompt) { 'a' * 500 }

      it 'truncates from the beginning by default' do
        allow(chat).to receive(:feedback)
        result = chat.guard_context_length(long_prompt, system,
                                           truncate: :leading)
        expect(result).to start_with('[content truncated]')
        expect(result).to end_with('a' * 20)
        expect(result.bytesize).to be < long_prompt.bytesize
      end

      it 'truncates from the end with truncate: :trailing' do
        allow(chat).to receive(:feedback)
        result = chat.guard_context_length(long_prompt, system,
                                           truncate: :trailing)
        expect(result).to start_with('a' * 20)
        expect(result).to end_with('[content truncated]')
        expect(result.bytesize).to be < long_prompt.bytesize
      end

      it 'logs a warning' do
        allow(chat).to receive(:feedback)
        expect(chat).to receive(:log).with(
          :warn,
          a_string_including('truncating'),
          anything
        )

        chat.guard_context_length(long_prompt, system,
                                  truncate: :leading)
      end

      it 'notifies the user via feedback' do
        expect(chat).to receive(:feedback).with(
          a_string_including('truncated'),
          type: :warn
        )

        chat.guard_context_length(long_prompt, system,
                                  truncate: :leading)
      end
    end
  end
end
