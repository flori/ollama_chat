describe OllamaChat::Tools::SearchKnowledge do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  connect_to_ollama_server

  it 'has the expected name' do
    expect(described_class.new(chat).name).to eq 'search_knowledge'
  end

  it 'provides a Tool instance' do
    expect(described_class.new(chat).tool).to be_a(Ollama::Tool)
  end

  it 'works with a valid query' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'search_knowledge',
        arguments: double(
          query: 'Ruby array',
          tags: nil,
          collection: nil,
          min_similarity: nil,
          text_size: nil,
          text_count: nil,
          rerank: false,
        )
      )
    )

    tool = described_class.new(chat)
    expect(chat).to receive(:find_document_records).with(
      kind_of(String), tags: nil, text_size: 16384, text_count: 10, min_similarity: nil
    ).and_return(
      [
        double(
          'Record',
          text:       'quux',
          source:     'foo',
          tags:       %w[ bar ],
          tags_set:   double('Tags', to_s: '', map: []),
          similarity: 0.666
        )
      ]
    )

    result = tool.execute(tool_call)

    # Should return a JSON string
    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.prompt).to eq(
      "Consider these snippets retrieved from the collection identified in the\n`collection` field when formulating your response.\n"
    )
    expect(json.snippets.size).to eq 1
    expect(json.message).to include('Retrieved')
    expect(json.message).to include('"Ruby array"')
  end

  it 'works with a valid query and tags' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'search_knowledge',
        arguments: double(
          query: 'Ruby array',
          tags: 'ruby,expert',
          collection: nil,
          min_similarity: nil,
          text_size: nil,
          text_count: nil,
          rerank: false,
        )
      )
    )

    tool = described_class.new(chat)
    expect(chat).to receive(:find_document_records).with(
      kind_of(String), tags: ['ruby', 'expert'], text_size: 16384, text_count: 10, min_similarity: nil
    ).and_return(
      [
        double(
          'Record',
          text:       'quintessential ruby',
          source:     'foo',
          tags:       %w[ ruby expert ],
          tags_set:   double('Tags', to_s: '', map: []),
          similarity: 0.666
        )
      ]
    )

    result = tool.execute(tool_call)

    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.snippets.size).to eq 1
    expect(json.message).to include('Retrieved')
    expect(json.message).to include('"Ruby array"')
  end

  it 'switches to the specified collection and restores the original' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'search_knowledge',
        arguments: double(
          query: 'Hobbits',
          tags: nil,
          collection: 'tolkien',
          min_similarity: nil,
          text_size: nil,
          text_count: nil,
          rerank: false,
        )
      )
    )

    mock_docs = double('Documents')
    expect(chat).to receive(:documents).and_return(mock_docs).at_least(:once)
    expect(chat).to receive(:database_collection?)
      .and_return(double('Col', description: 'Desc', enabled: true))
      .at_least(:once)

    expect(mock_docs).to receive(:collection).and_return('default_collection').
      at_least(:once)
    expect(mock_docs).to receive(:collection=).with('tolkien').ordered
    expect(mock_docs).to receive(:collection=).with('default_collection').ordered

    tool = described_class.new(chat)
    expect(chat).to receive(:find_document_records).and_return([])

    tool.execute(tool_call)
  end

  it 'raises an error for invalid collection names' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'search_knowledge',
        arguments: double(
          query: 'test',
          tags: nil,
          collection: 'invalid/collection',
          min_similarity: nil,
          text_size: nil,
          text_count: nil,
          rerank: false,
        )
      )
    )

    result = described_class.new(chat).execute(tool_call)
    json = json_object(result)
    expect(json.error).to eq('OllamaChat::ToolFunctionArgumentError')
    expect(json.message).to match(/Invalid collection name/)
  end

  it 'returns an error when query is empty' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'search_knowledge',
        arguments: double(
          query: '',
        )
      )
    )

    result = described_class.new(chat).execute(tool_call)
    json = json_object(result)
    expect(json.error).to eq('OllamaChat::OllamaChatError')
    expect(json.message).to eq('Empty query')
  end

  it 'returns a no-match message when no records are found' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'search_knowledge',
        arguments: double(
          query: 'nonexistent',
          tags: nil,
          collection: nil,
          min_similarity: nil,
          text_size: nil,
          text_count: nil,
          rerank: false,
        )
      )
    )

    tool = described_class.new(chat)
    expect(chat).to receive(:find_document_records).and_return([])

    result = tool.execute(tool_call)
    json = json_object(result)
    expect(json.message).to include('No relevant snippets found')
    expect(json.message).to include('"nonexistent"')
  end

  it 'performs reranking when rerank is true' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'search_knowledge',
        arguments: double(
          query: 'Ruby array',
          tags: nil,
          collection: nil,
          min_similarity: nil,
          text_size: nil,
          text_count: nil,
          rerank: true,
        )
      )
    )

    records = [
      double('Record', text: 'first', source: 's1', tags: [], tags_set: double('Tags', to_s: '', map: []), similarity: 0.1),
      double('Record', text: 'second', source: 's2', tags: [], tags_set: double('Tags', to_s: '', map: []), similarity: 0.9)
    ]

    tool = described_class.new(chat)
    expect(chat).to receive(:find_document_records).and_return(records)
    expect(chat).to receive(:database_collection?).and_return(double('Col', description: nil))
    expect(chat).to receive(:prompt).with('snippets_retrieval').and_return("Consider these snippets")

    expect(chat).to receive(:prompt).with('default', context: 'rerank').and_return("template %{query} %{candidates}")
    expect(chat).to receive(:generate).with(prompt: anything).and_return('1')

    result = tool.execute(tool_call)
    json = json_object(result)

    expect(json.snippets.size).to eq 1
    expect(json.snippets.first.text).to eq 'second'
    expect(json.message).to include('Retrieved')
    expect(json.message).to include('"Ruby array"')
  end

  it 'performs reranking when rerank is nil (defaults to true)' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'search_knowledge',
        arguments: double(
          query: 'Ruby array',
          tags: nil,
          collection: nil,
          min_similarity: nil,
          text_size: nil,
          text_count: nil,
          rerank: nil,
        )
      )
    )

    records = [
      double('Record', text: 'first', source: 's1', tags: [], tags_set: double('Tags', to_s: '', map: []), similarity: 0.1),
      double('Record', text: 'second', source: 's2', tags: [], tags_set: double('Tags', to_s: '', map: []), similarity: 0.9)
    ]

    tool = described_class.new(chat)
    expect(chat).to receive(:find_document_records).and_return(records)
    expect(chat).to receive(:database_collection?).and_return(double('Col', description: nil))
    expect(chat).to receive(:prompt).with('snippets_retrieval').and_return("Consider these snippets")

    expect(chat).to receive(:prompt).with('default', context: 'rerank').and_return("template %{query} %{candidates}")
    expect(chat).to receive(:generate).with(prompt: anything).and_return('0')

    result = tool.execute(tool_call)
    json = json_object(result)

    expect(json.snippets.size).to eq 1
    expect(json.snippets.first.text).to eq 'first'
    expect(json.message).to include('Retrieved')
    expect(json.message).to include('"Ruby array"')
  end

  it 'can be converted to hash' do
    expect(described_class.new(chat).to_hash).to be_a(Hash)
  end
end
