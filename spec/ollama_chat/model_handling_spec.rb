describe OllamaChat::ModelHandling do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config).expose
  end

  connect_to_ollama_server

  it 'can check if model_present? false' do
    expect(chat.ollama).to receive(:show).and_raise Ollama::Errors::NotFoundError
    expect(chat.model_present?('nixda')).to eq false
  end

  it 'can check if model_present? true' do
    stub_request(:post, %r(/api/show\z)).
      to_return(status: 200, body: asset_json('api_show.json'))
    model_metadata = chat.model_present?('llama3.1')
    expect(model_metadata.name).to eq 'llama3.1'
    expect(model_metadata.capabilities).to eq %w[ completion tools ]
  end

  it 'can pull_model_unless_present' do
    expect(chat).to receive(:model_present?).with('llama3.1').and_return false
    expect(chat).to receive(:model_present?).with('llama3.1').and_return true
    expect(chat).to receive(:pull_model_from_remote).with('llama3.1')
    expect(chat.pull_model_unless_present('llama3.1')).to eq true
  end
end
