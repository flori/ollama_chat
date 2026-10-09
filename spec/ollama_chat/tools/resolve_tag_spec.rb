describe OllamaChat::Tools::ResolveTag do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  connect_to_ollama_server

  before do
    const_conf_as(
      'OC::OLLAMA::CHAT::TOOLS::CTAGS_TOOL'  => 'true'
    )
  end

  it 'can have name' do
    expect(described_class.new(chat).name).to eq 'resolve_tag'
  end

  it 'can have tool' do
    expect(described_class.new(chat).tool).to be_a Ollama::Tool
  end

  it 'can be converted to hash' do
    expect(described_class.new(chat).to_hash).to be_a Hash
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
        and_return(double(resolve: double(size: 2, resolve: result_array)))

      result = described_class.new(chat).execute(tool_call)

      expect(result).to be_a String
      json = json_object(result)
      expect(json.results).to be_present
      expect(json.symbol).to  eq 'execute'
      expect(json.kind).to    eq ?f
      expect(described_class.summary_template(result:)).to eq \
        'Found 2 results of symbol "execute".'
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

      result = described_class.new(chat).execute(tool_call)

      json = json_object(result)
      expect(json.error).to eq('RuntimeError')
      expect(json.message).to include('some error')
      expect(described_class.summary_template(result:)).to include('some error')
    end
  end

  context 'when the tagged file does not exist' do
    let(:tags_path) { asset_tmp_path('tmp/test_tags.ctags') }

    before do
      FileUtils.mkdir_p(File.dirname(tags_path))
      # Valid ctags format: symbol\tfilename\t/^regexp$/;"\tkind rest
      # Points to lib/foo.rb which does not exist, so the tag is
      # silently skipped by the filename.exist? guard and 0 results
      # are returned.
      tags_path.write("execute\tlib/foo.rb\t/^  def execute\\($/;\"\tf method\n")
      const_conf_as(
        'OC::OLLAMA::CHAT::TOOLS::CTAGS_TOOL' => 'true',
        'OC::OLLAMA::CHAT::TOOLS::TAGS_FILE'  => tags_path,
      )
    end

    after do
      File.delete(tags_path) if File.exist?(tags_path)
    end

    it 'returns empty results without raising' do
      tool_call = double(
        'ToolCall',
        function: double(
          name: 'resolve_tag',
          arguments: double(symbol: 'execute', kind: nil, directory: nil)
        )
      )

      result = described_class.new(chat).execute(tool_call)
      json = json_object(result)

      expect(json.error).to be_nil
      expect(json.results).to eq []
      expect(json.message).to eq 'Found 0 results of symbol "execute".'
    end
  end
end
