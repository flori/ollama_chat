# A module that provides information and user agent functionality for
# OllamaChat
#
# The Information module encapsulates methods for managing application
# identification, displaying version and configuration details, and providing
# a modular information dashboard for chat sessions. It includes user agent
# capabilities for HTTP requests and provides focused information views.
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

    # The user_agent method constructs and returns a user agent string that
    # combines the program name and the OllamaChat version
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
  # @param output [IO] the output stream to write the message to
  def collection_stats(output: STDOUT)
    length       = (Tins::Terminal.cols - 10).clamp(0..)
    wrapped_tags = Kramdown::ANSI::Width.
      wrap(@documents.tags.to_a.join(', '), length:).
      gsub(/(?<!\A)^/, ' ' * 4)
    output.puts <<~EOT
      Current Collection
        Name: #{bold{collection}}
        #Embeddings: #{@documents.size}
        #Tags: #{@documents.tags.size}
        Tags:
          #{wrapped_tags}
    EOT
    nil
  end

  # Displays detailed information about the current chat model, including
  # capabilities, families, and configuration options.
  #
  # @param output [IO] the output stream to print the model information to
  #   (defaults to STDOUT).
  def info_model(output: STDOUT)
    output.puts "🧠 Current chat model is #{bold{@model}}."
    output.puts   "  Capabilities: #{Array(@model_metadata&.capabilities) * ', '}"
    output.puts   "  Families: #{Array(@model_metadata&.families) * ', '}"

    profiles = models::ModelOptions.where(model_name: @model).order(:profile).all
    if profiles.full?
      output.puts "  Stored Profile Options:"
      profiles.each do |p|
        output.puts <<~EOT.gsub(/^/, '      ')
          #{bold{p.profile}}:
            #{JSON.pretty_generate(p.options)}
        EOT
      end
    elsif config.model.options.full?
      output.puts "  Default Options: #{JSON.pretty_generate(mo).gsub(/(?<!\A)^/, '  ')}"
    end

    if model_options.present?
      output.puts "  Session Options: #{JSON.pretty_generate(model_options).gsub(/(?<!\A)^/, '  ')}"
    end
  end

  # Displays a detailed view of the current chat session state, including the
  # system prompt, persona, active model, thinking modes, tools, and audio settings.
  #
  # @param output [IO] the output stream to write the information to, defaults
  #   to STDOUT
  def info_session(output: STDOUT)
    output.print "🗣️ Current session: "; show_session(output:)
    output.puts "  Current Session Working Directory: \"#{bold{session.working_directory}}\""
    output.puts "  Current System Prompt: #{bold{current_system_prompt_name}}"
    if name = default_persona_name
      output.puts "  💃 Persona: #{bold{name}}"
    else
      output.puts "  No persona selected."
    end
    output.puts "🧠 Current chat model is #{bold{@model}}."
    output.print '  '; think_mode.show(output:)
    output.print '  '; think_loud.show(output:)
    output.print '  '; think_strip.show(output:)
    output.print '  🛠️ '; tools_support.show(output:)
    output.print '⚙️ Chat Settings'
    output.print '  '; markdown.show(output:)
    output.print '  '; stream.show(output:)
    output.print '  🎙️ '; voice.show(output:)
    if voice.on?
      output.print '  '; voices.show(output:)
    end
    output.print '  '; location.show(output:)
    output.print '  '; context_format.show(output:)
  end

  # Displays the current runtime environment details, split into static
  # (session-level) and dynamic (real-time) information.
  #
  # @param output [IO] the output stream to write the information to, defaults to STDOUT
  def info_runtime(output: STDOUT)
    output.puts "🏃 Runtime Information:"
    output.print '  '; runtime_info.show(output:)
    output.puts 'Static:'
    output.puts static_runtime_information_values.stringify_keys_recursive.to_yaml.
      sub(/\A---\s*\n/, '').gsub(/^/, '  ')
    output.puts 'Dynamic:'
    output.puts dynamic_runtime_information_values.stringify_keys_recursive.to_yaml.
      sub(/\A---\s*\n/, '').gsub(/^/, '  ')
  end

  # Displays information regarding the Retrieval Augmented Generation (RAG)
  # configuration, including the embedding model and collection statistics.
  #
  # @param output [IO] the output stream to write the information to, defaults to STDOUT
  def info_rag(output: STDOUT)
    if @embedding.on?
      output.puts "🗄️ Current RAG model is #{bold{@embedding_model}}"
      if @embedding_model_options.present?
        output.puts "  Options: #{JSON.pretty_generate(@embedding_model_options).gsub(/(?<!\A)^/, '  ')}"
      end
      output.puts "Text splitter is #{bold{config.embedding.splitter.name}}."
      collection_stats(output:)
    end
    @embedding.show(output:)
    output.puts "📜 Document policy for parsing in user text: #{bold{document_policy}}"
  end

  # The print_welcome method prints a welcome message containing the
  # application version, the connected ollama server version, and the server
  # URL.
  #
  # @param output [ IO ] the output stream where the welcome messages are
  #   printed (default: STDOUT)
  def print_welcome(output: STDOUT)
    output.puts "💎 Running ollama_chat version: #{bold{OllamaChat::VERSION}}"
    output.puts "🔌 Connected to ollama server version: #{bold{server_version}} on: #{bold{server_url}}"
  end

  # Displays a high-level summary dashboard of the current state of the
  # ollama_chat instance.
  #
  # @param output [IO] the output stream to write the information to, defaults
  #   to STDOUT
  def info(output: STDOUT)
    print_welcome(output:)
    output.puts "📜 Documents database cache is #{@documents.nil? ? 'n/a' : bold{@documents.cache.class}}"
    output.puts "🔎 Currently selected search engine is #{bold{search_engine}}."
    output.puts "🧠 Current chat model is #{bold{@model}}."
    output.puts "🗣️ Session: #{bold{@session.name}} (#{italic{@session.id}})"
    output.puts "  Current System Prompt: #{bold{current_system_prompt_name}}"
    if name = default_persona_name
      output.puts "  💃 Persona: #{bold{name}}"
    else
      output.puts "  No persona selected."
    end
    output.print '  🛠️ '; tools_support.show(output:)
    output.print '  🏃 '; runtime_info.show(output:)
    nil
  end

  # The display_chat_help method outputs the chat help message to standard
  # output, eventually using the configured pager.
  #
  # @param pattern [String, Regexp, nil] An optional pattern to filter
  #   the commands displayed in the help message.
  def display_chat_help(pattern = nil)
    use_pager do |output|
      output.puts help_message(pattern)
    end
    nil
  end

  # The usage method displays the command-line idea help text
  # and returns an exit code of 0.
  #
  # @return [ Integer ] always returns 0 indicating successful help display
  def usage
    STDOUT.puts <<~EOT
      Usage: #{progname} [OPTIONS]

        -f CONFIG      config file to read
        -l SESSION     load session with name/id SESSION
        -n             create a new session
        -u URL         the ollama base url, OLLAMA_URL
        -m MODEL       the ollama chat model, OLLAMA_CHAT_MODEL, ?selector
        -c CHAT        a saved chat conversation to load
        -C COLLECTION  name of the collection used in this conversation
        -D DOCUMENT    load document and add to embeddings collection (multiple)
        -M             use (empty) MemoryCache for this chat session
        -E             disable embeddings for this chat session
        -S             open a socket to receive input from ollama_chat_send
        -V             display the current version number and quit
        -h             this help

        Use `?selector` with `-m` or `-l` to filter options. Multiple matches
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

  # Retrieves the name of the chat user.
  #
  # @return [String] the chat user's name or 'n/a' if not set
  def user
    user_name || 'n/a'
  end

  # Retrieves the name of the chat user.
  #
  # @return [String] the chat user's name or nil if not set
  def user_name
    OC::OLLAMA::CHAT::USER
  end

  # Returns the infobar message configuration as a hash.
  #
  # This configuration is used by the `infobar` gem to define the progress
  # bar's format and spinner settings.
  #
  # @return [Hash] the infobar message configuration
  def infobar_message
    config.infobar.message.to_h
  end

  # Generates a hash containing static runtime information.
  #
  # This method collects session-level constants including the user,
  # language preferences, location, client version, working directory,
  # allowed tool paths, and available RAG collections.
  #
  # @return [Hash] a hash containing static runtime data.
  def static_runtime_information_values
    {
      client:               ,
      collections:          JSON.pretty_generate(config.embedding.collection_descriptions?),
      current_directory:    Pathname.pwd.expand_path.to_path,
      languages:            config.languages * ', ',
      location:             location.on?.full? { location_description } || 'n/a',
      tool_paths_allowed:   JSON.pretty_generate(tool_paths_allowed),
      user:                 ,
    }
  end

  # Generates a formatted string of static runtime information.
  #
  # This method interpolates the static runtime values into the
  # configured `static_runtime_info` prompt template.
  #
  # @return [String] a formatted static runtime information string.
  def static_runtime_information
    prompt(:static_runtime_info).to_s % static_runtime_information_values
  end

  # The dynamic_runtime_information_values method compiles a set of
  # volatile runtime details that change frequently.
  #
  # These include the current timestamp, weekday, session name, git
  # branch and origin, terminal dimensions, and feature switch statuses.
  #
  # @return [Hash] a hash containing dynamic runtime values.
  def dynamic_runtime_information_values
    now = Time.now
    {
      git_current_branch:   `git rev-parse --abbrev-ref HEAD 2>/dev/null`.chomp.full? || 'n/a',
      git_remote_origin:    `git remote get-url origin 2>/dev/null`.chomp.full? || 'n/a',
      git_sha:              `git rev-parse HEAD 2>/dev/null`.chomp.full? || 'n/a',
      git_sha_short:        `git rev-parse --short HEAD 2>/dev/null`.chomp.full? || 'n/a',
      markdown:             markdown.on? ? 'enabled' : 'disabled',
      session_name:         session.name,
      terminal_cols:        Tins::Terminal.cols,
      terminal_rows:        Tins::Terminal.rows,
      time:                 now.iso8601,
      tools_support:        tools_support.on? ? 'enabled' : 'disabled',
      voice:                voice.on? ? 'enabled' : 'disabled',
      weekday:              now.strftime('%A'),
    }
  end

  # The dynamic_runtime_information method generates a formatted string
  # containing real-time environment details (the "heartbeat").
  #
  # It returns the result of interpolating the dynamic values into the
  # configured `dynamic_runtime_info` prompt template.
  #
  # @return [String] the formatted dynamic runtime information string.
  def dynamic_runtime_information
    prompt(:dynamic_runtime_info).to_s % dynamic_runtime_information_values
  end
end
