require 'tins'
require 'tins/xt/string_version'
require 'tins/xt/full'
require 'json'
require 'term/ansicolor'
require 'reline'
require 'reverse_markdown'
require 'complex_config'
require 'fileutils'
require 'uri'
require 'nokogiri'
require 'rss'
require 'pdf/reader'
require 'csv'
require 'socket'
require 'shellwords'
require 'context_spook'

# A chat client for interacting with Ollama models through a terminal
# interface.
#
# The Chat class provides a complete command-line interface for chatting with
# language models via the Ollama API. It handles configuration management,
# message history, document processing, web searching, and various interactive
# features including voice output, markdown rendering, and embedding
# capabilities.
#
# @example Initializing a chat session
#   chat = OllamaChat::Chat.new(argv: ['-m', 'llama3.1'])
#
# @example Starting an interactive chat
#   chat.start
class OllamaChat::Chat
  include Tins::GO
  include Term::ANSIColor
  include OllamaChat::TokenEstimator
  include OllamaChat::HTTPHandling
  include OllamaChat::Commands
  include OllamaChat::Logging
  include OllamaChat::DocumentCache
  include OllamaChat::Switches
  include OllamaChat::StateSelectors
  include OllamaChat::ModelHandling
  include OllamaChat::Parsing
  include OllamaChat::SourceFetching
  include OllamaChat::WebSearching
  include OllamaChat::Dialog
  include OllamaChat::ThinkControl
  include OllamaChat::Information
  include OllamaChat::MessageOutput
  include OllamaChat::Clipboard
  include OllamaChat::MessageFormat
  include OllamaChat::Pager
  include OllamaChat::History
  include OllamaChat::ServerSocket
  include OllamaChat::KramdownANSI
  include OllamaChat::FileEditing
  include OllamaChat::Conversation
  include OllamaChat::InputContent
  include OllamaChat::MessageEditing
  include OllamaChat::LocationHandling
  include OllamaChat::ToolCalling
  include OllamaChat::ConfigHandling
  include OllamaChat::PersonaeManagement
  include OllamaChat::SessionManagement
  include OllamaChat::RAGHandling
  include OllamaChat::FavouritesManagement
  include OllamaChat::PromptHandling
  include OllamaChat::SystemPromptManagement
  include OllamaChat::PromptManagement
  include OllamaChat::Utils::Chooser
  include OllamaChat::Utils::ValueFormatter
  include OllamaChat::Utils::UTF8Converter

  # Initializes a new OllamaChat::Chat instance with the given command-line
  # arguments.
  #
  # Sets up the chat environment including configuration parsing, Ollama client
  # initialization, model selection, system prompt handling, document
  # processing setup, and history management. This method handles all the
  # bootstrapping necessary to create a functional chat session that can
  # communicate with an Ollama server and process various input types including
  # text, documents, web content, and images.
  #
  # The initialization process includes parsing command-line options using
  # Tins::GO for robust argument handling, setting up the Ollama client with
  # configurable timeouts (connect, read, write), validating Ollama API version
  # compatibility (requires >= 0.9.0 for features used), configuring model
  # selection based on command-line or configuration defaults, initializing
  # system prompts from files or inline content, setting up document processing
  # pipeline with embedding capabilities through Documentrix::Documents,
  # creating message history management through OllamaChat::MessageList,
  # initializing cache systems for document embeddings, setting up
  # voice support and image handling for multimodal interactions, enabling
  # optional server socket functionality for remote input, and handling
  # configuration errors with interactive recovery mechanisms.
  #
  # @param argv [Array<String>] Command-line arguments to parse (defaults to ARGV.dup)
  #
  # @raise [RuntimeError] If the Ollama API version is less than 0.9.0, indicating
  #   incompatibility with required API features
  def initialize(argv: ARGV.dup)
    @opts               = go 'f:u:m:c:C:D:l:nMESVh', argv
    @opts[?h] and exit usage
    @opts[?V] and exit version
    @ollama_chat_config = OllamaChat::OllamaChatConfig.new(@opts[?f])
    self.config         = @ollama_chat_config.config
    @messages           = OllamaChat::MessageList.new(self)
    OllamaChat::Database.setup_models.each { _1.ask_and_send(:seed, self) }
    setup_session
    setup_switches
    setup_state_selectors(config)
    connect_ollama
    if conversation_file = @opts[?c]
      messages.load_conversation(conversation_file)
    else
      messages.read_conversation_jsonl(session.messages.to_s)
    end
    embedding_enabled.set(config.embedding.enabled && !@opts[?E])
    @documents            = setup_documents
    @cache                = setup_cache
    @images               = []
    @kramdown_ansi_styles = configure_kramdown_ansi_styles
    @tool_call_results    = Hash.new { |h, name| h[name] = [] }
    setup_personae_directory
    @opts[?S] and init_server_socket
    info_session
  rescue ComplexConfig::AttributeMissing, ComplexConfig::ConfigurationSyntaxError => e
    fix_config(e)
  end

  # The ollama reader returns the Ollama API client instance.
  #
  # @return [Ollama::Client] the configured Ollama API client
  attr_reader :ollama

  # Returns the documents set for this object, initializing it lazily if
  # needed.
  #
  # The documents set is memoized, meaning it will only be created once per
  # object instance and subsequent calls will return the same
  # Documentrix::Documents instance.
  #
  # @return [Documentrix::Documents] A Documentrix::Documents object containing
  #   all documents associated with this instance
  attr_reader :documents

  # Returns the messages set for this object, initializing it lazily if needed.
  #
  # The messages set is memoized, meaning it will only be created once per
  # object instance and subsequent calls will return the same
  # OllamaChat::MessageList instance.
  #
  # @return [OllamaChat::MessageList] A MessageList object containing all
  #   messages associated with this instance
  attr_reader :messages

  # Returns the list of images currently queued for the next message.
  #
  # @return [Array] a list of images to be sent with the next prompt
  attr_reader :images

  # Provides read-only access to the cache instance used by the object
  #
  # @attr_reader [Cache] the cache instance
  attr_reader :cache

  # The start method initializes the chat session by displaying information,
  # then prompts the user for input to begin interacting with the chat.
  def start
    begin
      if model = session.current_model.full?
        use_model(model, keep_options: true)
      else
        use_model(initial_model)
      end
    rescue OllamaChat::UnknownModelError => e
      abort "Failed to use to model: #{e}"
    end

    STDOUT.puts

    setup_persona_from_session
    setup_system_prompt

    info_session

    STDOUT.puts "\nType /help to display the chat help."

    interact_with_user
  end

  # The debug method accesses the debug configuration setting.
  #
  # @return [TrueClass, FalseClass] the current debug mode status
  def debug
    OC::OLLAMA::CHAT::DEBUG
  end

  # Returns the model name to be used for the chat session.
  #
  # The resolution priority is:
  # 1. The current session's model (if present).
  # 2. The model specified via the command line option `-m`.
  # 3. The default model name defined in the configuration.
  #
  # @return [String] the model name to be used for the chat session
  def initial_model
    session&.current_model.full? || @opts[?m].full? || config.model.name
  end

  # The initial_collection method determines the collection name to be used for
  # embeddings in the RAG system.
  #
  # @return [ Symbol ] the collection name symbol
  def initial_collection
    (
      @opts[?C] ||
      session&.current_collection.full? ||
      config.embedding.collection.full? ||
      :default
    ).to_sym
  end

  # The initial_system_prompt method returns the system prompt for the initial
  # message.
  #
  # @return [String] the system prompt for the initial message
  def initial_system_prompt
    @messages.system_name
  end

  # Sends a structured chat request to the Ollama model and returns the
  # response content.
  #
  # This method creates a minimal conversation consisting of a system message
  # and a user message, executing it as a one-shot chat interaction.
  #
  # @param system [String] the system prompt to guide the model's behavior
  # (defaults to current raw_system_prompt)
  #
  # @param prompt [String] the user prompt to send to the model
  #
  # @return [String] the content of the resulting response message
  def generate(system: raw_system_prompt, prompt:)
    messages = [
      OllamaChat::Message.new(
        role:        'system',
        content:     system,
      ),

      OllamaChat::Message.new(
        role: 'user',
        content: prompt
      ),
    ]

    content = ollama.chat(
      model:    @model,
      messages: ,
      options:  model_options,
      stream:   false,
      think:    false,
      tools:
    )&.message&.content.to_s

    if content.empty?
      log(
        :warn,
        "Sent #{prompt.inspect} to LLM for generation, received no content!"
      )
    else
      log(
        :info,
        "Sent #{prompt.inspect} to LLM for generation, received #{content.inspect}"
      )
    end

    content
  end

  private

  # @return [Module] The module containing the database models.
  def models
    OllamaChat::Database::Models
  end

  # The disable_content_parsing method turns off content parsing by setting
  # `@parse_content` to false.
  #
  # This prevents automatic parsing of user input content during chat
  # processing.
  #
  # @return [self] returns the current instance to allow for method chaining
  def disable_content_parsing
    @parse_content = false
    self
  end

  # The enable_content_parsing method enables content parsing for the chat
  # session.
  #
  # @return [self] returns the current instance to allow for method chaining
  def enable_content_parsing
    @parse_content = true
    self
  end

  # The parse_content? method returns the boolean value of the @parse_content
  # instance variable.
  #
  # @return [TrueClass, FalseClass] true if @parse_content is truthy, false
  #   otherwise
  def parse_content?
    !!@parse_content
  end

  # Returns whether there is a prompt waiting to be prefilled into the input buffer.
  #
  # @return [Boolean] true if a prefill prompt exists and is not empty, false otherwise
  def prefill_prompt
    @prefill_prompt.full?
  end

  # Sets the content to be prefilled into the next user input prompt.
  #
  # @param prefill_prompt [String, nil] The text to prefill, or nil to clear it
  attr_writer :prefill_prompt

  # Handles user input commands and processes chat interactions.
  #
  # @param content [String] The input content to process
  # @return [Symbol, String, nil] Returns a symbol indicating next action,
  #   the content to be processed, or nil for no action needed
  def handle_input(content)
    commands.each do |_name, command|
      action = command.execute_if_match?(content) {}
      action and return action
    end
    content
  end

  # The clean method clears various parts of the chat session based on the
  # specified parameter.
  #
  # @param what [ String, nil ] the type of data to clear, defaults to
  #   'messages' if nil
  def clean(what)
    persona_profile = nil
    case what
    when 'messages', nil
      messages.clear
      STDOUT.puts "Cleared messages."
    when 'links'
      links.clear
      STDOUT.puts "Cleared links."
    when 'history'
      clear_history
      STDOUT.puts "Cleared history."
    when 'tags'
      @documents.clear
      STDOUT.puts "Cleared all tags."
    when 'images'
      messages.clear_images
      STDOUT.puts "Cleared all images."
    when 'all'
      if confirm?(
          prompt: '🔔 Are you sure to clear messages and collection? (y/n) ',
          yes: /\Ay/i
        )
      then
        messages.clear
        @documents.clear
        links.clear
        clear_history
        STDOUT.puts "Cleared messages and collection #{bold{collection}}."
      else
        STDOUT.puts 'Cancelled.'
      end
    end
    persona_profile
  end

  # The interact_with_user method manages the interactive loop for user input
  # and chat processing.
  # It handles reading user input, processing commands, managing messages, and
  # communicating with the Ollama server.
  # The method supports command completion, prefilling prompts, socket input
  # handling, and various chat features including embedding context and voice
  # support.
  # It processes user input through command handling, content parsing, and
  # message formatting before sending requests to the Ollama server.
  # The method also handles server socket messages, manages chat history, and
  # ensures proper cleanup and configuration handling throughout the
  # interaction.
  def interact_with_user
    loop do
      content           = nil
      tools_were_called = false
      enable_content_parsing
      type              = :terminal_input
      input_prompt      = bold { color(172) { message_type(@images) + " user" } } + bold { "> " }
      begin
        tools_were_called = handle_tool_call_results? { |index, tool_name, content|
          messages << OllamaChat::Message.new(
            role:        'user', # XXX this should be 'tool' but it doesn't currently seem to work in Ollama API
            sender_name: tool_name,
            tool_name:   ,
            content:     ,
            images:      @images.dup
          )
        }
        tools_were_called and type = :tool_input
        unless tools_were_called
          content = enable_command_completion do
            if prefill_prompt
              Reline.pre_input_hook = -> {
                Reline.insert_text prefill_prompt.gsub(/\n*\z/, '')
                self.prefill_prompt = nil
              }
            else
              Reline.pre_input_hook = nil
            end
            Reline.readline(input_prompt, true)&.chomp
          end
        end
      rescue Interrupt
        if message = server_socket_message
          type           = message.type.full?(:to_sym) || :socket_input
          content        = message.content
          @parse_content = message.parse
          STDOUT.puts color(112) { "Received a server socket message. Processing now…" }
        else
          raise
        end
      end

      content = content.strip if content =~ %r(\A/[^/])

      if type == :terminal_input
        case next_action = handle_input(content)
        when :next
          next
        when :redo
          redo
        when :return
          return
        when String
          content = next_action
        end
      end

      unless type == :tool_input
        content = content.encode(invalid: :replace)

        content.present? or next

        parse_content? and content = parse_content(content, @images)

        if runtime_info.on?
          tool_name = 'runtime_information'
          messages << OllamaChat::Message.new(
            role:        'user',
            tool_name:   ,
            sender_name: tool_name,
            content:     dynamic_runtime_information,
            images:      @images.dup
          )
        end

        messages << OllamaChat::Message.new(
          role:        'user',
          sender_name: user_name,
          content:     ,
          images:      @images.dup
        )
      end
      @images.clear
      handler = OllamaChat::FollowChat.new(
        chat:     self,
        messages:,
        voice:    (voices.selected if voice.on?)
      )
      begin
        retried = false
        sent_messages = messages.to_ary
        if think_strip.on?
          sent_messages = sent_messages.map {
            _1.dup.tap { |message|
              message.thinking = nil
            }
          }
        end
        prepare_model(@model)
        ollama.chat(
          model:    @model,
          messages: sent_messages,
          options:  model_options,
          stream:   stream.on?,
          think:    ,
          tools:    ,
          &handler
        )
        store_messages_in_session
      rescue Ollama::Errors::BadRequestError
        if (think? || tools_support.on?) && !retried
          STDOUT.puts "#{bold('Error')}: in think mode/with tool support, switch both off and retry."
          sleep 1
          think_mode.selected  = 'disabled'
          tools_support.set false
          retried = true
          retry
        else
          raise
        end
      end

      case type
      when :socket_input
        server_socket_message&.disconnect
      when :socket_input_with_response
        if message = handler.messages.last
          server_socket_message.respond({ role: message.role, content: message.content })
        end
        server_socket_message&.disconnect
      end
    rescue Ollama::Errors::TimeoutError
      msg = "Currently lost connection to ollama server and cannot send command."
      log(:warn, msg, warn: true)
    rescue Interrupt
      STDOUT.puts "Type /quit to quit."
    ensure
      self.server_socket_message = nil
    end
    0
  rescue ComplexConfig::AttributeMissing, ComplexConfig::ConfigurationSyntaxError => e
    log(:error, e)
    fix_config(e)
  ensure
    session_close
  end

  # The base_url method returns the Ollama server URL from command-line options
  # or environment configuration.
  #
  # @return [String] the base URL used for connecting to the Ollama API
  def base_url
    @opts[?u] || OC::OLLAMA::URL
  end

  # The connect_ollama method establishes a connection to the Ollama API server.
  #
  # This method initializes a new Ollama::Client instance with configured timeouts
  # and connection parameters, then verifies that the connected server meets the
  # minimum required API version (0.9.0). It sets the @ollama instance
  # variable to the configured client and stores the version in @server_version.
  #
  # @return [Ollama::Client] the configured Ollama client instance
  # @raise [RuntimeError] if the connected Ollama server API version is less
  #   than 0.9.0
  def connect_ollama
    @server_version = nil
    @ollama = Ollama::Client.new(
      connect_timeout: config.timeouts.connect_timeout?,
      read_timeout:    config.timeouts.read_timeout?,
      write_timeout:   config.timeouts.write_timeout?,
      base_url:        base_url,
      debug:           ,
      user_agent:
    )
    if server_version.version < '0.9.0'.version
      raise 'require ollama API version 0.9.0 or higher'
    end
    log(:info, "Connection to #{base_url} established.")
    @ollama
  end

  # The setup_documents method initializes the document processing pipeline by
  # configuring the embedding model and database connection.
  # It then loads specified documents into the system and returns the
  # configured document collection.
  #
  # @return [ Documentrix::Documents, NULL ] the initialized document
  #   collection if embedding is enabled, otherwise NULL
  def setup_documents
    if embedding.on?
      @embedding_model         = config.embedding.model.name
      @embedding_model_options = Ollama::Options[config.embedding.model.options]
      pull_model_unless_present(@embedding_model)
      collection = initial_collection
      @documents = Documentrix::Documents.new(
        ollama:,
        model:             @embedding_model,
        model_options:     config.embedding.model.options,
        embedding_length:  config.embedding.model.embedding_length,
        database_filename: config.embedding.database_filename || @ollama_chat_config.database_path,
        collection:        ,
        cache:             configure_cache,
        redis_url:         config.redis.documents.url?,
        debug:
      )

      document_list = @opts[?D].to_a
      add_documents_from_argv(document_list)
      @documents
    else
      NULL
    end
  end

  # Adds documents from command line arguments to the document collection
  #
  # Processes a list of document paths or URLs, handling both local files and
  # remote resources.
  #
  # @param document_list [Array<String>] List of document paths or URLs to process
  #
  # @example Adding local files
  #   add_documents_from_argv(['/path/to/file1.txt', '/path/to/file2.pdf'])
  #
  # @example Adding remote URLs
  #   add_documents_from_argv(['https://example.com/page1', 'http://example.com/page2'])
  #
  # @example Mixed local and remote
  #   add_documents_from_argv(['/local/file.txt', 'https://remote.com/document'])
  #
  # @note Empty entries in the document list will trigger a collection clear operation
  # @note Documents are processed in batches of 25 to manage memory usage
  # @note Progress is reported to STDOUT during processing
  def add_documents_from_argv(document_list)
    if document_list.any?(&:empty?)
      STDOUT.puts "Clearing collection #{bold{documents.collection}}."
      documents.clear
      document_list.reject!(&:empty?)
    end
    unless document_list.empty?
      document_list.map! do |doc|
        if doc =~ %r(\Ahttps?://)
          doc
        else
          File.expand_path(doc)
        end
      end
      STDOUT.puts "Collection #{bold{documents.collection}}: Adding #{document_list.size} documents…"
      count = 1
      document_list.each_slice(25) do |docs|
        docs.each do |doc|
          fetch_source(doc) do |doc_io|
            embed_source(doc_io, doc, count:)
          end
          count += 1
        end
      end
    end
  end

  # The setup_cache method initializes and returns a Redis cache instance with
  # expiring keys if a Redis URL is configured.
  #
  # @return [ OllamaChat::RedisCache, nil ] the configured Redis
  #   cache instance or nil if no URL is set.
  def setup_cache
    if url = config.redis.expiring.url?
      ex = config.redis.expiring.ex?.to_i
      OllamaChat::RedisCache.new(
        prefix: 'Expiring-',
        url:,
        ex:
      )
    end
  end

  # Enables tab completion for chat commands within the interactive session
  #
  # Temporarily replaces the current Reline completion procedure with a custom
  # one that provides command completion based on the chat help message.
  #
  # @param block [Proc] The block to execute with enhanced tab completion
  #   enabled
  #
  # @return [Object] The return value of the executed block
  def enable_command_completion(&block)
    old = Reline.completion_proc
    Reline.autocompletion = true
    Reline.completion_proc = -> input, pre {
      before = [ pre, input ].join
      case before
      when %r(^/)
        start = [ pre, input ].join(' ').strip.gsub(/\s+/, ' ')
        command_completions.select { _1.start_with?(start) }
      when %r((./\S*))
        OllamaChat::Utils::PathCompleter.new(pre, input).complete
      end
    }
    block.()
  ensure
    Reline.completion_proc = old
  end
end
