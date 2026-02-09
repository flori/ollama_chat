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
require 'ollama_chat/tools/browse'
require 'ollama_chat/tools/directory_structure'
require 'ollama_chat/tools/execute_grep'
require 'ollama_chat/tools/file_context'
require 'ollama_chat/tools/gem_path_lookup'
require 'ollama_chat/tools/get_current_weather'
require 'ollama_chat/tools/get_cve'
require 'ollama_chat/tools/get_endoflife'
require 'ollama_chat/tools/get_location'
require 'ollama_chat/tools/import_url'
require 'ollama_chat/tools/get_jira_issue'
require 'ollama_chat/tools/read_file'
require 'ollama_chat/tools/run_tests'
require 'ollama_chat/tools/search_web'
require 'ollama_chat/tools/vim_open_file'
require 'ollama_chat/tools/write_file'
