require 'spec_helper'

RSpec.describe OllamaChat::WebSearching do
  let :chat do
    OllamaChat::Chat.new
  end

  connect_to_ollama_server

  it 'can search web with duckduckgo' do
    url = 'https://www.duckduckgo.com/html/?q=foo'
    chat.config.web_search.engines.duckduckgo.attributes_update(url:)
    expect(chat).to receive(:search_engine).and_return 'duckduckgo'
    stub_request(:get, url).
      with(headers: { 'Host'=> 'www.duckduckgo.com' }).
      to_return(status: 200, body: asset_content('duckduckgo.html'), headers: {})
    expect(chat.search_web('foo').first.to_s).to eq(
      'https://en.wikipedia.org/wiki/Foo_Fighters'
    )
  end

  it 'can search web with searxng' do
    url = 'http://localhost:8088/search?format=json&language=en&q=foo'
    chat.config.web_search.engines.searxng.attributes_update(url:)
    expect(chat).to receive(:search_engine).and_return 'searxng'
    stub_request(:get, url).
      with(headers: { 'Host'=>'localhost:8088' }).
      to_return(status: 200, body: asset_content('searxng.json'), headers: {})
    expect(chat.search_web('foo').first.to_s).to eq(
      'https://en.wikipedia.org/wiki/Foo_Fighters'
    )
  end
end
