require 'spec_helper'

describe OllamaChat::Tools::ResolveTag do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  connect_to_ollama_server

  it 'can have name' do
    expect(described_class.new.name).to eq 'resolve_tag'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end

  context 'when executed successfully with a valid topic' do
    let(:symbol) { 'execute' }

    it 'returns JSON containing cmd and result' do
      tool_call = double(
        'ToolCall',
        function: double(
          name: 'resolve_tag',
          arguments: double(symbol:, kind: ?f, directory: nil)
        )
      )
      result_array = [
        {"message" => "execute of kind f (methods) at /Users/flori/scm/ollama_chat/lib/ollama_chat/tools/browse.rb:58",
         "kind_type" => "methods",
         "symbol" => "execute",
         "filename" => "/Users/flori/scm/ollama_chat/lib/ollama_chat/tools/browse.rb",
         "regexp" => "(?-mix:^\\ \\ def\\ execute\\(tool_call,\\ \\*\\*opts\\)$)",
         "kind" => "f",
         "linenumber" => 58},
         {"message" => "execute of kind f (methods) at /Users/flori/scm/ollama_chat/lib/ollama_chat/tools/copy_to_clipboard.rb:49",
          "kind_type" => "methods",
          "symbol" => "execute",
          "filename" => "/Users/flori/scm/ollama_chat/lib/ollama_chat/tools/copy_to_clipboard.rb",
          "regexp" => "(?-mix:^\\ \\ def\\ execute\\(tool_call,\\ \\*\\*opts\\)$)",
          "kind" => "f",
          "linenumber" => 49}
      ]
      expect(OllamaChat::Utils::TagResolver).to receive(:new).
        and_return(double(resolve: double(resolve: result_array)))

      result = described_class.new.execute(tool_call)

      expect(result).to be_a String
      json = json_object(result)
      expect(json.results).to be_present
      expect(json.symbol).to  eq 'execute'
      expect(json.kind).to    eq ?f
    end
  end

  context 'when resolver raises an exception' do
    before do
      allow_any_instance_of(OllamaChat::Utils::TagResolver).to receive(:resolve)
        .and_raise('my error')
    end

    it 'returns a JSON with the error class and message' do
      tool_call = double(
        'ToolCall',
        function: double(
          name: 'resolve_tag',
          arguments: double(symbol: 'FooBar', kind: ?c, directory: nil)
        )
      )

      expect(OllamaChat::Utils::TagResolver).to receive(:new).and_raise('some error')

      result = described_class.new.execute(tool_call, config: chat.config)

      json = json_object(result)
      expect(json.error).to eq('RuntimeError')
      expect(json.message).to include('some error')
    end
  end
end
