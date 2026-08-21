describe OllamaChat::Tools::Concern do
  # Use a tool that does NOT override `summary_template` for base-class tests.
  let :tool_class do
    OllamaChat::Tools::GetTime
  end

  let :tool do
    tool_class.new
  end

  describe '.summary_template' do
    it 'extracts the message field from valid JSON' do
      result = { message: 'The current time is 12:00 UTC.' }.to_json
      expect(tool_class.summary_template(result:))
        .to eq 'The current time is 12:00 UTC.'
    end

    it 'returns the generic fallback when message is absent' do
      result = { data: 'no-message-key' }.to_json
      expect(tool_class.summary_template(result:))
        .to eq 'was called.'
    end

    it 'returns the generic fallback for invalid JSON' do
      expect(tool_class.summary_template(result: 'not json'))
        .to eq 'was called.'
    end

    it 'returns the generic fallback for empty string' do
      expect(tool_class.summary_template(result: ''))
        .to eq 'was called.'
    end
  end

  describe '#name' do
    it 'returns the registered name' do
      expect(tool.name).to eq tool_class.register_name
    end
  end

  describe '#to_hash' do
    it 'delegates to tool.to_hash' do
      expect(tool.to_hash).to eq tool.tool.to_hash
    end

    it 'returns a hash with a function key' do
      expect(tool.to_hash).to have_key(:function)
    end
  end

  describe '#valid_json?' do
    it 'returns a proc' do
      expect(tool.valid_json?).to be_a Proc
    end

    it 'parses valid JSON from a temp file' do
      tmp = Tempfile.new('test.json')
      tmp.write({ key: 'value' }.to_json)
      tmp.rewind

      expect(tool.valid_json?.call(tmp)).to eq({ key: 'value' }.to_json)
    ensure
      tmp&.close!
    end

    it 'raises for empty content' do
      tmp = Tempfile.new('empty.json')
      tmp.write('')
      tmp.rewind

      expect { tool.valid_json?.call(tmp) }
        .to raise_error(JSON::ParserError, 'require JSON data')
    ensure
      tmp&.close!
    end
  end
end
