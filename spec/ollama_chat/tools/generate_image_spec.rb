describe OllamaChat::Tools::GenerateImage do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  connect_to_ollama_server

  before do
    const_conf_as(
      'OC::OLLAMA::CHAT::TOOLS::IMAGE_GENERATOR::WORKFLOW' => { '1.2' => { 'inputs' => { 'text' => 'before ' } } },
      'OC::OLLAMA::CHAT::TOOLS::IMAGE_GENERATOR::PROMPT_NODE_ID' => '1.2',
    )
  end

  let :service_url do
    URI.parse('http://localhost:8081')
  end

  it 'can have name' do
    expect(described_class.new.name).to eq 'generate_image'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  let :arguments do
    OpenStruct.new(
      prompt: 'A fluffy white kitten in a cyberpunk city',
      filename_prefix: 'fluffy-cyber'
    )
  end

  let :tool_call do
    double(
      'ToolCall',
      function: double(
        name:      'generate_image',
        arguments:
      )
    )
  end

  context 'when executing' do
    let(:instance) { described_class.new }

    it 'can be executed successfully' do
      allow(OC::OLLAMA::CHAT::TOOLS::IMAGE_GENERATOR).to receive(:URL?).
        and_return(service_url)
      # Mock the API sequence: prompt -> poll -> success
      expect(instance).to receive(:post_url).and_return(
        OpenStruct.new(prompt_id: '12345')
      )
      expect(instance).to receive(:poll_for_image).and_return('kitten_output.png')

      result = instance.execute(tool_call, chat:)

      expect(chat.links).to include(%r{/api/view.*filename=kitten_output.png})

      expect(result).to be_a(String)
      json = json_object(result)
      expect(json.status).to eq 'success'
      expect(json.url).to include('/api/view')
      expect(json.url).to include('filename=kitten_output.png')
    end

    it 'returns an error when prompt is missing' do
      arguments.prompt = nil

      result = instance.execute(tool_call, chat:)

      json = json_object(result)
      expect(json.error).to eq 'OllamaChat::ToolFunctionArgumentError'
      expect(json.message).to include('require prompt argument')
    end

    it 'returns an error when ComfyUI configuration is missing' do
      # Force a config error by simulating the OllamaChat::OllamaChatError
      allow(OC::OLLAMA::CHAT::TOOLS::IMAGE_GENERATOR).to receive(:URL?).and_return(nil)

      result = instance.execute(tool_call, chat:)

      json = json_object(result)
      expect(json.error).to eq 'OllamaChat::ConfigMissingError'
      expect(json.message).to include('Require env var OLLAMA_CHAT_TOOLS_IMAGE_GENERATOR_URL configuration')
    end

    it 'returns a timeout error when polling fails' do
      allow(OC::OLLAMA::CHAT::TOOLS::IMAGE_GENERATOR).to receive(:URL?).
        and_return(service_url)
      expect(instance).to receive(:post_url).and_return(
        OpenStruct.new(prompt_id: '12345')
      )
      expect(instance).to receive(:poll_for_image).and_return(nil)

      result = instance.execute(tool_call, chat:)

      json = json_object(result)
      expect(json.error).to eq 'OllamaChat::OllamaChatError'
      expect(json.message).to include('took too long or failed')
    end

    it 'handles API failures gracefully' do
      allow(OC::OLLAMA::CHAT::TOOLS::IMAGE_GENERATOR).to receive(:URL?).
        and_return(service_url)
      expect(instance).to receive(:post_url).and_return(
        OpenStruct.new(prompt_id: nil)
      )

      result = instance.execute(tool_call, chat:)

      json = json_object(result)
      expect(json.error).to eq 'OllamaChat::OllamaChatError'
      expect(json.message).to include('Failed to generate image: failed to trigger ComfyUI')
    end

    it 'rescues generic exceptions' do
      allow(OC::OLLAMA::CHAT::TOOLS::IMAGE_GENERATOR).to receive(:URL?).
        and_return(service_url)
      allow(instance).to receive(:post_url).and_raise(StandardError, 'Network crash')

      result = instance.execute(tool_call, chat:)

      json = json_object(result)
      expect(json.error).to eq 'StandardError'
      expect(json.message).to include('Network crash')
    end
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end
end
