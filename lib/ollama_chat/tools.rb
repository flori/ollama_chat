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

    # The register method adds a tool to the registry.
    #
    # @param tool [Object] the tool to be registered
    #
    # @return [Class] the class itself
    def register(tool)
      registered[tool.name] = tool
      self
    end
  end

  self.registered = {}
end
require 'ollama_chat/tools/weather'
OllamaChat::Tools.register OllamaChat::Tools::Weather.new
require 'ollama_chat/tools/cve'
OllamaChat::Tools.register OllamaChat::Tools::CVE.new
require 'ollama_chat/tools/endoflife'
OllamaChat::Tools.register OllamaChat::Tools::EndOfLife.new
