require 'spec_helper'

describe OllamaChat::Tools::GemPathLookup do
  it 'can have name' do
    expect(described_class.new.name).to eq 'gem_path_lookup'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end

  context 'when gem is found in bundle' do
    it 'returns JSON with gem information' do
      tool_call = double(
        'ToolCall',
        function: double(
          name: 'gem_path_lookup',
          arguments: double(
            gem_name: 'json'
          )
        )
      )
      result = described_class.new.execute(tool_call)

      # Should return a JSON string
      expect(result).to be_a(String)
      json = json_object(result)
      expect(json.gem_name).to eq 'json'
      expect(json.found).to eq true
      expect(json.path).to be_present
      expect(json.version).to be_present
    end
  end

  context 'when gem is not found in bundle' do
    it 'returns JSON indicating gem not found' do
      tool_call = double(
        'ToolCall',
        function: double(
          name: 'gem_path_lookup',
          arguments: double(
            gem_name: 'nonexistent_gem'
          )
        )
      )
      result = described_class.new.execute(tool_call)

      expect(result).to be_a(String)
      json = json_object(result)
      expect(json.gem_name).to eq 'nonexistent_gem'
      expect(json.found).to eq false
      expect(json.message).to be_present
    end
  end

  context 'when exception occurs' do
    it 'returns error JSON string' do
      tool_call = double(
        'ToolCall',
        function: double(
          name: 'gem_path_lookup',
          arguments: double(
            gem_name: 'json'
          )
        )
      )

      expect(Bundler).to receive(:locked_gems).and_raise 'an error has happened'
      result = described_class.new.execute(tool_call)

      # Should return a JSON string
      expect(result).to be_a(String)
      json = json_object(result)
      expect(json.error).to eq 'RuntimeError'
      expect(json.message).to eq 'an error has happened'
    end
  end
end
