if ENV['START_SIMPLECOV'].to_i == 1
  require 'simplecov'
  SimpleCov.start do
    add_filter "#{File.basename(File.dirname(__FILE__))}/"
  end
end
require 'rspec'
require 'tins/xt/expose'
begin
  require 'debug'
rescue LoadError
end
require 'webmock/rspec'
WebMock.disable_net_connect!
require 'ollama_chat'

ComplexConfig::Provider.deep_freeze = false

def asset(name)
  File.join(__dir__, 'assets', name)
end

def asset_content(name)
  File.read(File.join(__dir__, 'assets', name))
end

def asset_io(name, &block)
  io = File.new(File.join(__dir__, 'assets', name))
  if block
    begin
      block.call(io)
    ensure
      io.close
    end
  else
    io
  end
end

def asset_json(name)
  JSON(JSON(File.read(asset(name))))
end

def connect_to_ollama_server(instantiate: true)
  before do
    stub_request(:get, %r(/api/tags\z)).
      to_return(status: 200, body: asset_json('api_tags.json'))
    stub_request(:post, %r(/api/show\z)).
      to_return(status: 200, body: asset_json('api_show.json'))
    stub_request(:get, %r(/api/version\z)).
      to_return(status: 200, body: asset_json('api_version.json'))
    instantiate and chat
  end
end

RSpec.configure do |config|
  config.before(:suite) do
    infobar.show = nil
  end
end
