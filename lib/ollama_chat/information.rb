# A module that provides information and user agent functionality for
# OllamaChat
#
# The Information module encapsulates methods for managing application
# identification, displaying version and configuration details, and handling
# command-line interface help messages. It includes user agent capabilities for
# HTTP requests and provides comprehensive information display features for
# chat sessions.
#
# @example Displaying application information
#   chat.info
#
# @example Showing version details
#   chat.version
#
# @example Displaying usage help
#   chat.usage
module OllamaChat::Information
  extend Tins::Concern

  included do
    include UserAgent
    extend UserAgent
  end

  # A module that provides user agent functionality for identifying the
  # application.
  #
  # This module encapsulates methods for determining the application name and
  # constructing a standardized user agent string that includes the application
  # name and version. It is designed to be included in classes that need to
  # provide identification information for HTTP requests or other
  # communications.
  #
  # @example Accessing the program name
  #   UserAgent.progname # => "ollama_chat"
  #
  # @example Generating a user agent string
  #   UserAgent.user_agent # => "ollama_chat/0.0.25"
  module UserAgent
    # The progname method returns the name of the application.
    #
    # @return [ String ] the application name "ollama_chat"
    def progname
      'ollama_chat'
    end

    # The user_agent method constructs and returns a user agent string
    # that combines the program name and the OllamaChat version
    # separated by a forward slash.
    #
    # @return [ String ] the formatted user agent string
    def user_agent
      [ progname, OllamaChat::VERSION ] * ?/
    end
  end

  # The client method returns the application name and its current version as a
  # single string
  #
  # @return [ String ] the progname followed by the OllamaChat version
  #   separated by a space
  def client
    [ progname, OllamaChat::VERSION ] * ' '
  end

  # The collection_stats method displays statistics about the current document
  # collection.
  #
  # This method outputs information regarding the active document collection,
  # including the collection name, total number of embeddings, and a list of
  # tags.
  #
  # @return [ nil ] This method always returns nil.
  def collection_stats
    STDOUT.puts <<~EOT
      Current Collection
        Name: #{bold{@documents.collection}}
        #Embeddings: #{@documents.size}
        #Tags: #{@documents.tags.size}
        Tags: #{@documents.tags}
    EOT
    nil
  end

  # The info method displays comprehensive information about the current state
  # of the ollama_chat instance.
  # This includes version details, server connection status, model
  # configurations, embedding settings, and various operational switches.
  #
  # @return [ nil ] This method does not return a value; it outputs information
  #   directly to standard output.
  def info
    STDOUT.puts "Running ollama_chat version: #{bold(OllamaChat::VERSION)}"
    STDOUT.puts "Connected to ollama server version: #{bold(server_version)} on: #{bold(server_url)}"
    STDOUT.puts "Current conversation model is #{bold{@model}}."
    STDOUT.puts   "  Capabilities: #{Array(@model_metadata&.capabilities) * ', '}"
    if @model_options.present?
      STDOUT.puts "  Options: #{JSON.pretty_generate(@model_options).gsub(/(?<!\A)^/, '  ')}"
    end
    @embedding.show
    if @embedding.on?
      STDOUT.puts "Current embedding model is #{bold{@embedding_model}}"
      if @embedding_model_options.present?
        STDOUT.puts "  Options: #{JSON.pretty_generate(@embedding_model_options).gsub(/(?<!\A)^/, '  ')}"
      end
      STDOUT.puts "Text splitter is #{bold{config.embedding.splitter.name}}."
      collection_stats
    end
    markdown.show
    stream.show
    think_mode.show
    think_loud.show
    location.show
    voice.show
    @voice.on? and @voices.show
    if runtime_info.on?
      STDOUT.puts "Runtime Information:"
      STDOUT.puts runtime_information_values.transform_keys(&:to_s).to_yaml.
        sub(/\A---\s*\n/, '').gsub(/^/, '  ')
    else
      runtime_info.show
    end
    tools_support.show
    STDOUT.puts "Documents database cache is #{@documents.nil? ? 'n/a' : bold{@documents.cache.class}}"
    STDOUT.puts "Document policy for references in user text: #{bold{document_policy}}"
    STDOUT.puts "Currently selected search engine is #{bold(search_engine)}."
    name = default_persona_name and STDOUT.puts "Default persona: #{bold{name}}"
    STDOUT.puts "Conversation length: #{bold(@messages.size.to_s)} message(s)."
    nil
  end

  # The display_chat_help method outputs the chat help message to standard
  # output, evenutally using the configured pager.
  #
  # @return [ nil ] This method always returns nil after printing the help
  #   message.
  def display_chat_help
    use_pager do |output|
      output.puts help_message
    end
    nil
  end

  # The usage method displays the command-line interface help text
  # and returns an exit code of 0.
  #
  # @return [ Integer ] always returns 0 indicating successful help display
  def usage
    STDOUT.puts <<~EOT
      Usage: #{progname} [OPTIONS]

        -f CONFIG      config file to read
        -u URL         the ollama base url, OLLAMA_URL
        -m MODEL       the ollama model to chat with, OLLAMA_CHAT_MODEL, ?selector
        -s SYSTEM      the system prompt to use as a file, OLLAMA_CHAT_SYSTEM, ?selector
        -p PERSONA     load a persona via name/file for roleplay at startup
        -c CHAT        a saved chat conversation to load
        -C COLLECTION  name of the collection used in this conversation
        -D DOCUMENT    load document and add to embeddings collection (multiple)
        -M             use (empty) MemoryCache for this chat session
        -E             disable embeddings for this chat session
        -S             open a socket to receive input from ollama_chat_send
        -V             display the current version number and quit
        -h             this help

        Use `?selector` with `-m` or `-s` to filter options. Multiple matches
        will open a chooser dialog.
    EOT
    0
  end

  # The version method outputs the program name and its version number to
  # standard output.
  #
  # @return [ Integer ] returns 0 indicating successful execution
  def version
    STDOUT.puts "%s %s" % [ progname, OllamaChat::VERSION ]
    0
  end

  # The server_version method retrieves the version of the Ollama server.
  #
  # @return [ String ] the version string of the connected Ollama server
  def server_version
    @server_version ||= ollama.version.version
  end

  # The server_url method returns the base URL of the Ollama server connection.
  #
  # @return [ String ] the base URL used for communicating with the Ollama API
  def server_url
    @server_url ||= ollama.base_url
  end

  # The runtime_information_values method compiles a set of key runtime details
  # such as languages, location description, default persona name, current git
  # branch and remote origin, client agent string, current directory, terminal
  # dimensions, timestamp, voice and markdown status, and allowed tool paths.
  #
  # @return [Hash] a hash containing runtime information values.
  def runtime_information_values
    {
      languages:            config.languages * ', ',
      time:                 Time.now.iso8601,
      location:             location.on?.full? { location_description } || 'n/a',
      default_persona:      default_persona_name.full? || 'n/a',
      git_current_branch:   `git rev-parse --abbrev-ref HEAD 2>/dev/null`.chomp.full? || 'n/a',
      git_remote_origin:    `git remote get-url origin 2>/dev/null`.chomp.full? || 'n/a',
      client:               ,
      current_directory:    Pathname.pwd.expand_path.to_path,
      terminal_rows:        Tins::Terminal.rows,
      terminal_cols:        Tins::Terminal.cols,
      voice:                voice.on? ? 'enabled' : 'disabled',
      markdown:             markdown.on? ? 'enabled' : 'disabled',
      tool_paths_allowed:   JSON.pretty_generate(tool_paths_allowed),
    }
  end

  # The runtime_information method generates a formatted string containing
  # various runtime values such as languages, location description, git branch
  # and origin, client agent, current directory, terminal size, time, voice and
  # markdown status, and allowed tool paths.
  # It returns the result of interpolating these values into the configured
  # runtime_info prompt template.
  #
  # @return [String] the formatted runtime information string.
  def runtime_information
    config.prompts.runtime_info % runtime_information_values
  end
end
