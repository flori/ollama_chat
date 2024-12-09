require 'spec_helper'

RSpec.describe OllamaChat::SourceFetching do
  let :chat do
    OllamaChat::Chat.new
  end

  before do
    stub_request(:get, %r(/api/tags\z)).
      to_return(status: 200, body: asset_json('api_tags.json'))
    stub_request(:post, %r(/api/show\z)).
      to_return(status: 200, body: asset_json('api_show.json'))
    allow(chat).to receive(:location).and_return(double(on?: false))
  end

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

  it 'can search web' do
    stub_request(:get, "https://www.duckduckgo.com/html/?q=foo").
      with(headers: { 'Host'=>'www.duckduckgo.com' }).
      to_return(status: 200, body: asset_content('duckduckgo.html'), headers: {})
    expect(chat.search_web('foo').first.to_s).to eq(
      'https://en.wikipedia.org/wiki/Foo_Fighters'
    )
  end
end
