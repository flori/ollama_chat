# A module that provides utility classes and methods for the OllamaChat
# application.
#
# The Utils module serves as a namespace for various helper components that
# support the core functionality of OllamaChat. It contains implementations for
# caching, interactive selection, content fetching, and file argument handling
# that are used throughout the application to provide robust and user-friendly
# features.
module OllamaChat::Utils
end

require 'ollama_chat/utils/cache_fetcher'
require 'ollama_chat/utils/chooser'
require 'ollama_chat/utils/fetcher'
require 'ollama_chat/utils/file_argument'
require 'ollama_chat/utils/analyze_directory'
require 'ollama_chat/utils/path_validator'
