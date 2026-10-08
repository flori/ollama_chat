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
    #   (as class or instance).
    attr_accessor :registered

    # Returns the tool class for a registered tool name.
    #
    # @param name [String, #to_s] the registered tool name
    # @return [Class] the tool class
    # @raise [ArgumentError] if no tool with the given name is registered
    def registered_class(name)
      name = name.to_s
      registered.key?(name) or raise ArgumentError, 'tool %s not registered'
      tool = registered[name]
      if tool.is_a?(Class)
        tool
      else
        tool.class
      end
    end

    # Instantiates a registered tool, binding it to the given chat session.
    #
    # The registry stores tool classes (not instances). This method
    # produces a fresh instance with the chat reference injected via
    # `Concern#initialize(chat)`, making `self.chat` available for
    # config access and feedback during execution.
    #
    # @param name [String, #to_s] the registered tool name
    # @param chat [OllamaChat::Chat] the chat session to bind
    # @return [OllamaChat::Tools::Concern, nil] a tool instance, or nil
    #   if the tool is not registered
    def registered_tool(name, chat:)
      name = name.to_s
      case tool = registered[name]
      when NilClass
        nil
      when Class
        tool.new(chat)
      else
        tool
      end
    end

    # Registers a tool class in the registry.
    #
    # The class (not an instance) is stored. Instantiation is deferred
    # to `registered_tool(name, chat:)` at request time, so each
    # invocation gets a fresh instance bound to the current session.
    #
    # @param tool [Class] the tool class to register
    # @return [OllamaChat::Tools] the current instance after registration
    # @raise [ArgumentError] if the tool has no `register_name` or is
    #   already registered
    def register(tool)
      name = tool.register_name.to_s
      name.present? or raise ArgumentError, 'tool needs a name'
      registered.key?(name) and
        raise ArgumentError, 'tool %s already registered' % name
      registered[name] = tool
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
require 'ollama_chat/tools/compute_bmi'
require 'ollama_chat/tools/copy_to_clipboard'
require 'ollama_chat/tools/delete_file'
require 'ollama_chat/tools/eval_ruby'
require 'ollama_chat/tools/execute_grep'
require 'ollama_chat/tools/execute_ri'
require 'ollama_chat/tools/execute_shell'
require 'ollama_chat/tools/execute_jira_twg'
require 'ollama_chat/tools/file_context'
require 'ollama_chat/tools/forget'
require 'ollama_chat/tools/list_directory'
require 'ollama_chat/tools/lookup_gem_path'
require 'ollama_chat/tools/generate_image'
require 'ollama_chat/tools/generate_password'
require 'ollama_chat/tools/get_current_weather'
require 'ollama_chat/tools/get_cve'
require 'ollama_chat/tools/get_endoflife'
require 'ollama_chat/tools/get_ghr'
require 'ollama_chat/tools/get_jira_issue'
require 'ollama_chat/tools/get_location'
require 'ollama_chat/tools/get_rfc'
require 'ollama_chat/tools/get_time'
require 'ollama_chat/tools/get_url'
require 'ollama_chat/tools/lookup_group'
require 'ollama_chat/tools/memorize'
require 'ollama_chat/tools/move_file'
require 'ollama_chat/tools/open_file_in_editor'
require 'ollama_chat/tools/paste_from_clipboard'
require 'ollama_chat/tools/paste_into_editor'
require 'ollama_chat/tools/patch_file'
require 'ollama_chat/tools/read_file'
require 'ollama_chat/tools/resolve_tag'
require 'ollama_chat/tools/search_knowledge'
require 'ollama_chat/tools/roll_dice'
require 'ollama_chat/tools/run_tests'
require 'ollama_chat/tools/search_web'
require 'ollama_chat/tools/write_file'
