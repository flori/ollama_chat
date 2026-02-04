# The main module namespace for the OllamaChat application.
#
# This module serves as the root namespace for all components of the OllamaChat
# Ruby gem, providing access to core classes, utilities, and configuration
# management for interacting with Ollama language models through a terminal
# interface.
#
# @example Accessing the main module
#   OllamaChat::VERSION # => "0.0.25"
module OllamaChat
end

require 'ollama'
require 'documentrix'
require 'unix_socks'
require 'ollama_chat/version'
require 'ollama_chat/utils'
require 'ollama_chat/redis_cache'
require 'ollama_chat/message_format'
require 'ollama_chat/ollama_chat_config'
require 'ollama_chat/follow_chat'
require 'ollama_chat/switches'
require 'ollama_chat/state_selectors'
require 'ollama_chat/message_list'
require 'ollama_chat/model_handling'
require 'ollama_chat/parsing'
require 'ollama_chat/source_fetching'
require 'ollama_chat/web_searching'
require 'ollama_chat/dialog'
require 'ollama_chat/think_control'
require 'ollama_chat/information'
require 'ollama_chat/message_output'
require 'ollama_chat/clipboard'
require 'ollama_chat/vim'
require 'ollama_chat/document_cache'
require 'ollama_chat/history'
require 'ollama_chat/server_socket'
require 'ollama_chat/kramdown_ansi'
require 'ollama_chat/conversation'
require 'ollama_chat/input_content'
require 'ollama_chat/message_editing'
require 'ollama_chat/env_config'
require 'ollama_chat/tools'
require 'ollama_chat/tool_calling'
require 'ollama_chat/chat'
