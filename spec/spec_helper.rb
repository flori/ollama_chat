begin
  require 'gem_hadar/simplecov'
  GemHadar::SimpleCov.start
rescue LoadError
end
require 'rspec'
require 'tins/xt/expose'
begin
  require 'debug'
rescue LoadError
end
require 'webmock/rspec'
WebMock.disable_net_connect!
require 'const_conf/spec'
require 'ollama_chat'

ComplexConfig::Provider.deep_freeze = false

# A module that provides helper methods for asset management within the
# application.
#
# The AssetHelpers module encapsulates functionality related to handling and
# processing application assets, such as CSS, JavaScript, and image files. It
# offers utilities for managing asset paths, generating URLs, and performing
# operations on assets during the application's runtime.
module AssetHelpers
  # The asset method constructs and returns the full path to an asset file.
  #
  # This method takes a filename argument and combines it with the assets directory
  # located within the same directory as the calling file, returning the
  # complete path to that asset.
  #
  # @param name [String] the name of the asset file
  #
  # @return [String] the full path to the asset file
  def asset(name = nil)
    File.join(*[__dir__, 'assets', name ].compact)
  end

  # Reads and returns the content of an asset file from the assets directory.
  #
  # @param name [String] the name of the asset file to read
  #
  # @return [String] the content of the asset file as a string
  def asset_content(name)
    File.read(File.join(__dir__, 'assets', name))
  end

  # The asset_io method retrieves an IO object for a specified asset file.
  #
  # This method constructs the path to an asset file within the assets directory
  # and returns an IO object representing that file. If a block is provided, it
  # yields the IO object to the block and ensures the file is properly closed
  # after the block executes.
  #
  # @param name [ String ] the name of the asset file to retrieve
  #
  # @yield [ io ] yields the IO object for the asset file to the provided block
  #
  # @return [ File, nil ] returns the IO object for the asset file, or nil if a
  #   block is provided and the block does not return a value
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

  # The asset_json method reads and parses a JSON asset file.
  #
  # This method retrieves an asset by name, reads its contents from the
  # filesystem, and then parses the resulting string as JSON, returning the
  # parsed data structure.
  #
  # @param name [String] the name of the asset to retrieve and parse
  #
  # @return [Object] the parsed JSON data structure, typically a Hash or Array
  def asset_json(name)
    JSON(JSON(File.read(asset(name))))
  end
end

# A module that provides helper methods for application functionality.
#
# The AppHelper module encapsulates various utility methods that support core
# application operations, including JSON object parsing and chat configuration
# management.
#
# @example Using the json_object method
#   json_object('{"key": "value"}')
#
# @example Using the chat_default_config method
#   chat_default_config(['-m', 'llama3.1'])
module AppHelper
  # The json_object method parses a JSON string into a structured object.
  #
  # @param json_string [ String ] a JSON formatted string to be parsed
  #
  # @return [ JSON::GenericObject ] the parsed JSON object with generic object
  #   class
  def json_object(json_string)
    json_string.full? or return
    JSON.parse(json_string, object_class: JSON::GenericObject)
  end

  # The chat_default_config method constructs a default configuration array for
  # chat sessions.
  #
  # This method initializes a configuration array with a default config file
  # path and any additional arguments provided.
  #
  # @param argv [Array<String>] an array of additional arguments to prepend to the
  #   default config
  #
  # @return [Array<String>] a new array containing the default config file path
  #   and any additional arguments
  def chat_default_config(argv = [])
    argv + %w[ -f lib/ollama_chat/ollama_chat_config/default_config.yml ]
  end
end

# A module that provides functionality for stubbing Ollama server responses.
#
# The StubOllamaServer module enables developers to simulate Ollama API
# interactions in test environments by intercepting requests and returning
# predefined responses. This allows for faster, more reliable testing without
# requiring external service calls.
module StubOllamaServer
  # The connect_to_ollama_server method establishes a connection to an Ollama
  # server.
  #
  # This method sets up stubbed HTTP requests to simulate responses from an
  # Ollama server, including API tags, show, and version endpoints. It can
  # optionally instantiate a chat session after setting up the stubs.
  #
  # @param instantiate [Boolean] whether to instantiate a chat session after setting up stubs
  def connect_to_ollama_server(instantiate: true)
    before do
      stub_request(:get, %r(/api/tags\z)).
        to_return(status: 200, body: asset_json('api_tags.json'))
      stub_request(:post, %r(/api/show\z)).
        to_return(status: 200, body: asset_json('api_show.json'))
      stub_request(:get, %r(/api/version\z)).
        to_return(status: 200, body: asset_json('api_version.json'))
      allow_any_instance_of(OllamaChat::Chat).to receive(:connect_message)
      instantiate and chat
    end
  end
end

# A module that provides functionality for protecting environment variables
# during tests.
#
# This module ensures that environment variable changes made during test
# execution are automatically restored to their original values after the test
# completes. It is designed to prevent side effects between tests that modify
# environment variables, maintaining a clean testing environment.
module ProtectEnvVars
  # The apply method creates a lambda that protects environment variables
  # during test execution.
  #
  # @return [Proc] a lambda that wraps test execution with environment variable
  #   preservation
  def self.apply
    -> example do
      if example.metadata[:protect_env]
        begin
          stored_env = ENV.to_h
          example.run
        ensure
          ENV.replace(stored_env)
        end
      else
        example.run
      end
    end
  end
end

RSpec.configure do |config|
  config.include AppHelper
  config.include AssetHelpers
  config.extend StubOllamaServer

  config.before(:suite) do
    infobar.show = nil
  end

  config.around(&ProtectEnvVars.apply)
  config.include(ConstConf::ConstConfHelper)
end
