describe OllamaChat::Speaker do
  # Minimal harness that includes Speaker and records every #call invocation.
  let(:handler) do
    Class.new do
      include OllamaChat::Speaker

      attr_reader :calls

      def initialize
        @calls = []
      end

      def call(response)
        @calls << response
        self
      end
    end.new
  end

  describe '#speak' do
    context 'inline (background: false)' do
      it 'delegates to #call with the text and done: true' do
        result = handler.speak('hello world')

        expect(result).to be_nil
        expect(handler.calls.size).to eq 1
        expect(handler.calls.first.response).to eq 'hello world'
        expect(handler.calls.first.done).to be true
      end

      it 'passes the exact text through unchanged' do
        handler.speak("line one\nline two")

        expect(handler.calls.first.response).to eq "line one\nline two"
      end
    end

    context 'background (background: true)' do
      it 'returns self for chaining with #cancel_speaking' do
        result = handler.speak('bg', background: 0.05)

        expect(result).to be handler
        sleep 0.1
        expect(handler.calls.size).to eq 1
        expect(handler.calls.first.response).to eq 'bg'
      end
    end

    context 'delayed background (background: numeric)' do
      it 'spawns a thread that sleeps before speaking' do
        started_at = Time.now
        handler.speak('delayed', background: 0.2)
        sleep 0.3
        elapsed = Time.now - started_at

        expect(handler.calls.size).to eq 1
        expect(elapsed).to be >= 0.15
      end
    end
  end

  describe '#cancel_speaking' do
    it 'returns self for chaining' do
      expect(handler.cancel_speaking).to be handler
    end

    it 'is safe to call with no pending speak' do
      handler.cancel_speaking
      expect(handler.calls).to be_empty
    end

    it 'prevents a pending delayed background speak from calling #call' do
      handler.speak('should never appear', background: 5)
      handler.cancel_speaking
      sleep 0.1

      expect(handler.calls).to be_empty
    end
  end

  describe '#wait_for_speaker' do
    it 'is a no-op when no background thread exists' do
      expect { handler.wait_for_speaker }.not_to raise_error
    end

    it 'joins a completed background thread' do
      handler.speak('bg', background: 0.05)
      sleep 0.1
      expect { handler.wait_for_speaker }.not_to raise_error
    end
  end
end
