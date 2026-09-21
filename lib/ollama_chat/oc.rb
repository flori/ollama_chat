require 'const_conf'
require 'pathname'
require 'shellwords'

# Environment configuration module for OllamaChat
#
# This module provides a structured way to manage environment variables and
# configuration settings for the OllamaChat application. It uses the
# ConstConf library to define and manage configuration parameters with
# default values, descriptions, and decoding logic.
#
# The module organizes configuration into logical sections including general
# settings, Ollama-specific configurations, and chat-specific options.
module OC
  include ConstConf

  plugin ConstConf::JSONPlugin

  description 'Environment config for OllamaChat'
  prefix ''

  XDG_CONFIG_HOME = set do
    description 'XDG Configuration home directory path'
    default { '~/.config' }
    decode  { Pathname.new(_1).join('ollama_chat').expand_path }
  end

  XDG_CACHE_HOME = set do
    description 'XDG Cache home directory path'
    default { '~/.cache' }
    decode  { Pathname.new(_1).join('ollama_chat').expand_path }
  end

  XDG_STATE_HOME = set do
    description 'XDG State home directory path'
    default { '~/.local/state' }
    decode  { Pathname.new(_1).join('ollama_chat').expand_path }
  end

  PAGER = set do
    description 'Pager command to use in case terminal lines are exceeded by output'

    default do
      if fallback_pager = `which 2>/dev/null less`.full?(:chomp) || `which 2>/dev/null more`.full?(:chomp)
        fallback_pager << ' -r'
      end
    end
  end

  EDITOR = set do
    description 'Editor to use'

    default do
      if  editor = %w[ vim vi ].find { `which 2>/dev/null #{_1}`.full?(:chomp) }
        editor
      else
        warn 'Need an editor command configured via env var "EDITOR"'
      end
    end
  end

  BROWSER = set do
    description 'Browser to use'

    default do
      %w[ open xdg-open ].find { `which 2>/dev/null #{_1}` }.full?(:chomp)
    end
  end

  DIFF_COMMAND = set do
    description 'Command (string) to generate a unified diff with'

    required true
    default { 'diff -u --color=always' }
    decode { Shellwords.split(_1) if _1.present? }
  end

  DIFF_TOOL = set do
    description 'Diff tool to apply changes with'

    default do
      if  diff = `which 2>/dev/null vimdiff`.full?(:chomp)
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
      default     { 'http://%s' % OC::OLLAMA::HOST }
      sensitive   true
      decode { URI.parse(_1) if _1.present? }
      check { value.scheme =~ /\Ahttps?\z/ }
    end

    SEARXNG_URL = set do
      description 'URL for the SearXNG service for searches'
      default     'http://localhost:8088/search?q=%{query}&language=en&format=json'
      sensitive   true
      check { value =~ /\Ahttps?/ }
    end

    REDIS_URL = set do
      description 'Redis URL for documents'
      default     { ENV['REDIS_URL'].full?  }
      sensitive   true
      decode { URI.parse(_1) if _1.present? }
      check { value.nil? || value.scheme == 'redis' }
    end

    REDIS_EXPIRING_URL = set do
      description 'Redis URL for caching'
      default     { OC::OLLAMA::REDIS_URL? || ENV['REDIS_URL'].full? }
      sensitive   true
      decode { URI.parse(_1) if _1.present? }
      check { value.nil? || value.scheme == 'redis' }
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
        default     XDG_STATE_HOME + 'history.jsonl'
      end

      module LOG
        description 'Logging configuration'

        CHAT = set do
          description 'Chat log file path'
          default     XDG_STATE_HOME + 'chat.log'
        end

        DATABASE = set do
          description 'Database log file path'
          default     XDG_STATE_HOME + 'database.log'
        end

        TAIL_LINES = set do
          description 'Max lines to keep in log files (truncate older)'
          default     10_000
          decode      { Integer(_1) }
        end
      end

      USER = set do
        description '(Full) Name of the chat user'
        default     { ENV['USER'] }
      end

      TTS_URL = set do
        description 'Base URL for the TTS (Text-to-Speech) service'
        default     'http://localhost:8880'
        required    true
        sensitive   true
        decode      { URI.parse(_1) if _1.present? }
        check       { value.scheme =~ /\Ahttps?\z/ }
      end

      AUDIO_PLAYER_CONFIG = set do
        description <<~EOT
          Audio player configuration (JSON with four keys):

          command   – Shell command that receives raw PCM on stdin.
                      Opened via IO.popen(cmd, "w"); the playback thread
                      writes audio bytes and silence chunks to its stdin.
                      Default: ffplay s16le 24 kHz mono pipe.

          frequency – Sample rate in Hz (e.g. 24000). Used to compute
                      the byte size of silence chunks: frequency ×
                      (bits / 8) × pause.

          bits      – Bit depth per sample (e.g. 16). Determines bytes
                      per sample for silence chunk calculation.

          pause     – Seconds of silence injected when the audio queue
                      is empty. Prevents the playback process from
                      seeing EOF and hanging. Also the sleep duration
                      between silence writes.
        EOT
        default <<~EOT
          {
            "command": "ffplay -autoexit -nodisp -loglevel quiet -vn -volume 80 -f s16le -ar 24000 -ch_layout mono -i -",
            "frequency": 24000,
            "bits": 16,
            "pause": 0.01
          }
        EOT
        decode  json
        check   { value.command && value.frequency && value.bits && value.pause if value.present? }
      end

      module ASR
        description 'ASR (Speech-to-Text) service configuration'

        URL = set do
          description 'Base URL for the ASR (Speech-to-Text) service'
          default     'http://localhost:8880'
          required    true
          sensitive   true
          decode      { URI.parse(_1) if _1.present? }
          check       { value.scheme =~ /\Ahttps?\z/ }
        end

        CONVERT_COMMAND = set do
          description <<~EOT
            Shell command template to convert video sources to 16 kHz mono
            PCM WAV. Use %{input} for the source path and %{output} for the
            target WAV path.
          EOT
          default     'ffmpeg -y -i %{input} -vn -acodec pcm_s16le -ar 16000 -ac 1 %{output}'
          required    true
        end

        MODEL = set do
          description 'ASR model identifier (e. g. qwen3-asr-1.7b)'
          default     'qwen3-asr-1.7b'
          required    true
        end
      end

      module INVIDIOUS
        description 'Invidious instance (YouTube proxy) configuration'

        URL = set do
          description 'Base URL for the Invidious instance'
          sensitive   true
          decode      { URI.parse(_1) if _1.present? }
          check       { value.blank? || value.scheme =~ /\Ahttps?\z/ }
        end

        COMPANION_KEY = set do
          description 'Bearer token for the Invidious companion player API'
          sensitive   true
          required    { OC::OLLAMA::CHAT::INVIDIOUS::URL? }
        end

        CAPTION_LANGUAGES = set do
          description 'Priority list of language-code regexes for caption selection'
          default     %q{ [ "\\\\Aen\\\\z", "\\\\Aen-", "\\\\Ade\\\\z", "\\\\Ade-" ] }
          required    true
          decode      { json.(_1).map { |s| Regexp.new(s) } }
        end
      end

      module TOOLS
        description 'Tool specific configuration settings'

        # Run Tests tool configuration
        TEST_RUNNER = set do
          description <<~EOT
            Test runner command template. Use %{path} to specify where the test
            path argument goes; otherwise it is appended at the end.
          EOT

          default     'rspec'
          required     true
        end

        PIRATEWEATHER_API_KEY = set do
          description 'Pirate Weather API key'
        end

        CTAGS_TOOL = set do
          description 'Tools ctags path'
          default { `which 2>/dev/null ctags`.full?(:chomp) }
          check   { value.blank? || File.exist?(value) }
        end

        TAGS_FILE = set do
          description 'Tag file location'
          default     './tags'
          decode       { Pathname.new(_1).expand_path }
        end

        GHR_URL = set do
          description 'Base URL for GHR api server, e. g. https://ghr.example.com'
          sensitive   true
          decode { URI.parse(_1) if _1.present? }
          check { value.blank? || value.scheme =~ /\Ahttps?\z/ }
        end

        RUBY_EVAL_IMAGE_TEMPLATE = set do
          description <<~EOT
            Docker image template for ruby, e. g. "ruby:%{version}-alpine",
            version will be substitued with the ruby version requested.'
          EOT
          default 'ruby:%{version}-alpine'
          required true
        end

        module JIRA
          description 'Jira tool configuration'

          URL = set do
            description 'Base URL for Jira instance'
            sensitive   true
            decode { URI.parse(_1) if _1.present? }
            check { value.blank? || value.scheme == 'https' }
          end

          USER = set do
            description 'Username for Jira authentication'
            sensitive   true
            required { OC::OLLAMA::CHAT::TOOLS::JIRA::URL? }
          end

          API_TOKEN = set do
            description 'API token for Jira authentication'
            sensitive   true
            required { OC::OLLAMA::CHAT::TOOLS::JIRA::URL? }
          end

          TWG = set do
            description 'Path to the twg CLI binary'
            default { `which 2>/dev/null twg`.full?(:chomp) }
          end
        end

        module IMAGE_GENERATOR
          description 'Image generator configuration'

          URL = set do
            description 'Base URL for ComfyUI image generator server'
            sensitive   true
            decode { URI.parse(_1) if _1.present? }
            check { value.blank? || value.scheme =~ /\Ahttps?\z/ }
          end

          WORKFLOW = set do
            description 'ComfyUI workflow as JSON string'
            required { OC::OLLAMA::CHAT::TOOLS::IMAGE_GENERATOR::URL? }
            decode { JSON.parse(_1).freeze if _1.present? }
          end

          PROMPT_NODE_ID = set do
            description 'Prompt node id for the image generating text prompt'
            required { OC::OLLAMA::CHAT::TOOLS::IMAGE_GENERATOR::URL? }
          end

          FILENAME_PREFIX_NODE_ID = set do
            description 'Node id for the image filename prefix'
          end
        end
      end
    end
  end
end
