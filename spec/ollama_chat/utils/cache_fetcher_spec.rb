require 'spec_helper'

RSpec.describe OllamaChat::Utils::CacheFetcher do
  let :url do
    'https://www.example.com/hello'
  end

  let :cache do
    double('RedisCache')
  end

  let :fetcher do
    described_class.new(cache).expose
  end

  it 'can be instantiated' do
    expect(fetcher).to be_a described_class
  end

  it 'has #get' do
    expect(cache).to receive(:[]).with('body-69ce405ab83f42dffa9fd22bbd47783f').and_return 'world'
    expect(cache).to receive(:[]).with('content_type-69ce405ab83f42dffa9fd22bbd47783f').and_return 'text/plain'
    yielded_io = nil
    block = -> io { yielded_io = io }
    fetcher.get(url, &block)
    expect(yielded_io).to be_a StringIO
    expect(yielded_io.read).to eq 'world'
  end

  it '#get needs block' do
    expect { fetcher.get(url) }.to raise_error(ArgumentError)
  end

  it 'has #put' do
    io = StringIO.new('world')
    io.extend(OllamaChat::Utils::Fetcher::HeaderExtension)
    io.content_type = MIME::Types['text/plain'].first
    io.ex = 666
    expect(cache).to receive(:set).with('body-69ce405ab83f42dffa9fd22bbd47783f', 'world', ex: 666)
    expect(cache).to receive(:set).with('content_type-69ce405ab83f42dffa9fd22bbd47783f', 'text/plain', ex: 666)
    fetcher.put(url, io)
  end
end
