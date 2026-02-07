require 'const_conf'
require 'pathname'

module OllamaChat
  # Environment configuration module for OllamaChat
  #
  # This module provides a structured way to manage environment variables and
  # configuration settings for the OllamaChat application. It uses the
  # ConstConf library to define and manage configuration parameters with
  # default values, descriptions, and decoding logic.
  #
  # The module organizes configuration into logical sections including general
  # settings, Ollama-specific configurations, and chat-specific options.
  module EnvConfig
    include ConstConf

    description 'Environment config for OllamaChat'
    prefix ''

    XDG_CONFIG_HOME = set do
      description 'XDG Configuration directory path'
      default { '~/.config' }
      decode  { Pathname.new(_1) + 'ollama_chat' }
    end

    XDG_CACHE_HOME = set do
      description 'XDG Cache directory path'
      default { '~/.cache' }
      decode  { Pathname.new(_1) + 'ollama_chat' }
    end

    PAGER = set do
      description 'Pager command to use in case terminal lines are exceeded by output'

      default do
        if fallback_pager = `which less`.full?(:chomp) || `which more`.full?(:chomp)
          fallback_pager << ' -r'
        end
      end
    end

    EDITOR = set do
      description 'Editor to use'

      default do
        if  editor = %w[ vim vi ].find { `which #{_1}`.full?(:chomp) }
          editor
        else
          warn 'Need an editor command configured via env var "EDITOR"'
        end
      end
    end

    BROWSER = set do
      description 'Browser to use'

      default do
        %w[ open xdg-open ].find { `which #{_1}` }.full?(:chomp)
      end
    end

    DIFF_TOOL = set do
      description 'Diff tool to apply changes with'

      default do
        if  diff = `which vimdiff`.full?(:chomp)
          diff
        else
          warn 'Need a diff tool configured via env var "DIFF_TOOL"'
        end
      end
    end

    KRAMDOWN_ANSI_OLLAMA_CHAT_STYLES = set do
      description 'Styles to use for kramdown-ansi markdown'

      default ENV['KRAMDOWN_ANSI_STYLES'].full?
    end

    module OLLAMA
      description 'Ollama Configuration'
      prefix 'OLLAMA'

      HOST = set do
        description 'Ollama "host" to connect to'
        default     'localhost:11434'
      end

      URL = set do
        description 'Ollama base URL to connect to'
        default     { 'http://%s' % OllamaChat::EnvConfig::OLLAMA::HOST }
        sensitive   true
      end

      SEARXNG_URL = set do
        description 'URL for the SearXNG service for searches'
        default     'http://localhost:8088/search?q=%{query}&language=en&format=json'
        sensitive   true
      end

      REDIS_URL = set do
        description 'Redis URL for documents'
        default     { ENV['REDIS_URL'].full?  }
        sensitive   true
      end

      REDIS_EXPIRING_URL = set do
        description 'Redis URL for caching'
        default     { EnvConfig::OLLAMA::REDIS_URL? || ENV['REDIS_URL'].full? }
        sensitive   true
      end

      module CHAT
        description 'OllamaChat Configuration'

        DEBUG = set do
          description 'Enable debugging for chat client'
          decode { _1.to_i == 1 }
          default 0
        end

        MODEL = set do
          description 'Default model to use for the chat'
          default 'llama3.1'
        end

        SYSTEM = set do
          description 'Default system prompt'
        end

        COLLECTION = set do
          description 'Default collection for embeddings'
        end

        HISTORY = set do
          description 'File to save the chat history in'
          default     XDG_CACHE_HOME + 'history.json'
        end
      end
    end
  end
end
