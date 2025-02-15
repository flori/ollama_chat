require 'spec_helper'

RSpec.describe OllamaChat::ModelHandling do
  let :chat do
    OllamaChat::Chat.new
  end

  connect_to_ollama_server

  it 'can check if model_present?' do
    expect(chat.ollama).to receive(:show).and_raise Ollama::Errors::NotFoundError
    expect(chat.model_present?('nixda')).to eq false
    expect(chat.ollama).to receive(:show).and_return 'llama3.1'
    expect(chat.model_present?('llama3.1')).to be_truthy
  end

  it 'can pull_model_from_remote' do
    stub_request(:post, %r(/api/pull\z)).
      to_return(status: 200, body: asset_json('api_show.json'))
    expect(chat.pull_model_from_remote('llama3.1'))
  end

  it 'can pull_model_unless_present' do
    expect(chat).to receive(:model_present?).with('llama3.1').and_return false
    expect(chat).to receive(:model_present?).with('llama3.1').and_return true
    expect(chat).to receive(:pull_model_from_remote).with('llama3.1')
    expect(chat.pull_model_unless_present('llama3.1', {}))
  end
end
