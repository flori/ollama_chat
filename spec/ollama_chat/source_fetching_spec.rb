require 'spec_helper'

RSpec.describe OllamaChat::SourceFetching do
  let :chat do
    OllamaChat::Chat.new
  end

  connect_to_ollama_server

  it 'can import' do
    expect(chat.import('./spec/assets/example.html')).to start_with(<<~EOT)
      Imported "./spec/assets/example.html":

      # My First Heading

      My first paragraph.
    EOT
  end

  it 'can summarize' do
    expect(chat.summarize('./spec/assets/example.html')).to start_with(<<~EOT)
      Generate an abstract summary of the content in this document using
      100 words:

      # My First Heading

      My first paragraph.
    EOT
  end

  it 'can embed' do
    expect(chat).to receive(:fetch_source).with(
      './spec/assets/example.html'
    )
    expect(chat.embed('./spec/assets/example.html')).to eq(
      'This source was now embedded: ./spec/assets/example.html'
    )
  end
end
