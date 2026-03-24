describe OllamaChat::Tools::RetrieveDocumentSnippets do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  connect_to_ollama_server

  it 'has the expected name' do
    expect(described_class.new.name).to eq 'retrieve_document_snippets'
  end

  it 'provides a Tool instance' do
    expect(described_class.new.tool).to be_a(Ollama::Tool)
  end

  it 'works with a valid query' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'retrieve_document_snippets',
        arguments: double(
          query: 'Ruby array',
          # other attributes are irrelevant for this tool
        )
      )
    )

    tool = described_class.new
    expect(tool).to receive(:find_document_records).with(
      kind_of(OllamaChat::Chat), kind_of(String)
    ).and_return(
      [ double('Record', text: 'quux', source: 'foo', tags: %w[ bar ], tags_set: []) ]
    )

    result = tool.execute(tool_call, chat:)

    # Should return a JSON string
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.prompt).to eq(
      "Consider these snippets generated from retrieval when formulating your response!"
    )
    expect(json.ollama_chat_retrieval_snippets.size).to eq 1
  end

  it 'returns an error when query is empty' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'retrieve_document_snippets',
        arguments: double(
          query: '',
        )
      )
    )

    result = described_class.new.execute(tool_call, chat:)
    json = json_object(result)
    expect(json.error).to eq('OllamaChat::OllamaChatError')
    expect(json.message).to eq('Empty query')
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a(Hash)
  end
end
