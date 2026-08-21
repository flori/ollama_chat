describe OllamaChat::Message do
  describe 'OllamaChat::MessageMixin' do
    let :group_uuid do
      '0194a3f2-8c4d-7e1a-b3c1-2f9e5a6b7c8d'
    end

    let :message do
      described_class.new(
        role: 'user',
        content: 'Hello World',
        thinking: 'Let me think about this...',
      )
    end

    describe '#token_estimate' do
      it 'excludes thinking when strip_thinking is true' do
        # "Hello World" is 11 bytes
        # 11 / 3.5 = 3.14 → ceil = 4
        es = message.token_estimate(strip_thinking: true)
        expect(es).to be_a OllamaChat::TokenEstimator::Estimate
        expect(es.bytes).to eq 11
        expect(es.tokens).to eq 4
      end

      it 'includes thinking content by default (strip_thinking: false)' do
        es = message.token_estimate
        # "Hello World" (11) + "Let me think about this..." (26) = 37 bytes
        # 37 / 3.5 = 10.57 → ceil = 11
        expect(es.bytes).to eq 37
        expect(es.tokens).to eq 11
      end

      it 'handles nil content gracefully' do
        msg = described_class.new(role: 'user', content: nil)
        es = msg.token_estimate
        expect(es.bytes).to eq 0
        expect(es.tokens).to eq 0
      end

      it 'handles nil thinking gracefully' do
        msg = described_class.new(role: 'user', content: 'Hi', thinking: nil)
        es = msg.token_estimate
        expect(es.bytes).to eq 2
      end

      it 'handles both nil content and thinking' do
        msg = described_class.new(role: 'user', content: nil, thinking: nil)
        es = msg.token_estimate
        expect(es.bytes).to eq 0
        expect(es.tokens).to eq 0
      end
    end

    describe '#group_time' do
      it 'returns nil when group_uuid is missing' do
        expect(message.group_time).to be_nil
      end

      it 'extracts the timestamp from a UUIDv7' do
        msg  = described_class.new(
          role: 'user', content: 'Hi', group_uuid:,
        )
        expected = Time.parse('2025-01-26 19:49:29+0100')
        expect(msg.group_time).to be_within(5).of(expected)
      end

      it 'returns a Time close to now for a freshly generated UUID' do
        msg = described_class.new(role: 'user', content: 'Hi')
        msg.initialize_group_uuid
        diff = (Time.now - msg.group_time).abs
        expect(diff).to be < 5.0
      end
    end

    describe '#initialize_group_uuid' do
      it 'generates a UUIDv7 when missing' do
        msg = described_class.new(role: 'user', content: 'Hi')
        expect(msg.group_uuid).to be_nil
        msg.initialize_group_uuid
        expect(msg.group_uuid).to match(/\A[0-9a-f-]{36}\z/)
      end

      it 'preserves an existing group_uuid' do
        uuid = '0194a3f2-8c4d-7e1a-b3c1-2f9e5a6b7c8d'
        msg = described_class.new(role: 'user', content: 'Hi', group_uuid: uuid)
        msg.initialize_group_uuid
        expect(msg.group_uuid).to eq uuid
      end

      it 'returns self for chaining' do
        msg = described_class.new(role: 'user', content: 'Hi')
        expect(msg.initialize_group_uuid).to be msg
      end
    end

    describe '#tool?' do
      it 'returns true when tool_name is present' do
        msg = described_class.new(
          role: 'tool', content: 'result', tool_name: 'read_file',
        )
        expect(msg.tool?).to be true
      end

      it 'returns false when tool_name is nil' do
        expect(message.tool?).to be false
      end
    end

    describe '#as_json' do
      it 'includes sender_name and group_uuid when set' do
        msg = described_class.new(
          role: 'user', content: 'Hi', sender_name: 'Florian', group_uuid:
        )
        json = msg.as_json
        expect(json[:sender_name]).to eq 'Florian'
        expect(json[:group_uuid]).to  eq group_uuid
      end

      it 'omits nil sender_name and group_uuid' do
        json = message.as_json
        expect(json).not_to have_key(:sender_name)
        expect(json).not_to have_key(:group_uuid)
      end
    end
  end
end
