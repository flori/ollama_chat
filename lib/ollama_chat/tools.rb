require 'shellwords'

# A module that provides tool registration and management for OllamaChat.
#
# The Tools module serves as a registry for available tools that can be invoked
# during chat conversations. It maintains a collection of registered tools and
# provides methods for registering new tools and accessing the complete set of
# available tools for use in chat interactions.
module OllamaChat::Tools
  class << self
    # The registered attribute reader
    #
    # @return [ Hash ] the registered tools hash containing all available tools
    attr_accessor :registered

    # The register method adds a new tool to the registry.
    #
    # @param tool [ Object ] the tool to be registered
    # @return [ OllamaChat::Tools ] the current instance after registration
    def register(tool)
      name = tool.register_name.to_s
      name.present? or raise ArgumentError, 'tool needs a name'
      registered.key?(name) and
        raise ArgumentError, 'tool %s already registered' % name
      registered[name] = tool.new
      self
    end

    # Checks if a tool with the given name is registered.
    #
    # @param register_name [ String, #to_s ] the name of the tool to check
    #
    # @return [ TrueClass, FalseClass ] true if the tool is registered, false
    #   otherwise
    def registered?(register_name)
      registered.key?(register_name.to_s)
    end
  end

  self.registered = {}
end
require 'ollama_chat/tools/concern'
require 'ollama_chat/tools/weather'
require 'ollama_chat/tools/cve'
require 'ollama_chat/tools/endoflife'
require 'ollama_chat/tools/location'
require 'ollama_chat/tools/file_context'
require 'ollama_chat/tools/directory_structure'
require 'ollama_chat/tools/grep'
require 'ollama_chat/tools/browser'
require 'ollama_chat/tools/search_web'
