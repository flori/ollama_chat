require 'tins'
require 'tins/secure_write'
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
  include OllamaChat::History
  include OllamaChat::ServerSocket
  include OllamaChat::KramdownANSI
  include OllamaChat::Conversation
  include OllamaChat::InputContent
  include OllamaChat::MessageEditing
  include OllamaChat::LocationHandling
  include OllamaChat::ToolCalling

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
    @opts               = go 'f:u:m:s:c:C:D:MESVh', argv
    @opts[?h] and exit usage
    @opts[?V] and exit version
    @messages           = OllamaChat::MessageList.new(self)
    @ollama_chat_config = OllamaChat::OllamaChatConfig.new(@opts[?f])
    self.config         = @ollama_chat_config.config
    setup_switches(config)
    setup_state_selectors(config)
    connect_ollama
    @model           = choose_model(@opts[?m], config.model.name)
    @model_options   = Ollama::Options[config.model.options]
    model_system     = pull_model_unless_present(@model, @model_options)
    embedding_enabled.set(config.embedding.enabled && !@opts[?E])
    if @opts[?c]
      messages.load_conversation(@opts[?c])
    else
      default = config.system_prompts.default? || model_system
      if @opts[?s] =~ /\A\?/
        change_system_prompt(default, system: @opts[?s])
      else
        system = OllamaChat::Utils::FileArgument.get_file_argument(@opts[?s], default:)
        system.present? and messages.set_system_prompt(system)
      end
    end
    @documents            = setup_documents
    @cache                = setup_cache
    @images               = []
    @kramdown_ansi_styles = configure_kramdown_ansi_styles
    init_chat_history
    @opts[?S] and init_server_socket
    @enabled_tools = config.tools.to_h.map { |n, v| n.to_s if v[:default] }.compact
    @tool_call_results = {}
  rescue ComplexConfig::AttributeMissing, ComplexConfig::ConfigurationSyntaxError => e
    fix_config(e)
  end

  # The document_policy reader returns the document policy selector for the chat session.
  #
  # @return [ OllamaChat::StateSelector ] the document policy selector object
  #   that manages the policy for handling document references in user text
  attr_reader :document_policy

  # The think_mode reader returns the think mode selector for the chat session.
  #
  # @return [ OllamaChat::StateSelector ] the think mode selector object
  #   that manages the thinking mode setting for the Ollama model interactions
  attr_reader :think_mode

  # The debug method accesses the debug configuration setting.
  #
  # @return [TrueClass, FalseClass] the current debug mode status
  def debug
    OllamaChat::EnvConfig::OLLAMA::CHAT::DEBUG
  end

  # The ollama reader returns the Ollama API client instance.
  #
  # @return [Ollama::Client] the configured Ollama API client
  attr_reader :ollama

  # Returns the documents set for this object, initializing it lazily if needed.
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

  # Returns the links set for this object, initializing it lazily if needed.
  #
  # The links set is memoized, meaning it will only be created once per object
  # instance and subsequent calls will return the same Set instance.
  #
  # @return [Set] A Set object containing all links associated with this instance
  def links
    @links ||= Set.new
  end

  class << self
    # The config attribute accessor provides read and write access to the
    # configuration object associated with this instance.
    attr_accessor :config
  end

  # The config= method assigns a new configuration object to the class.
  #
  # @param config [ ComplexConfig::Settings ] the configuration object to be set
  def config=(config)
    self.class.config = config
  end

  # The config method returns the configuration object associated with the
  # class.
  #
  # @return [ ComplexConfig::Settings ] the configuration instance
  def config
    self.class.config
  end

  # The start method initializes the chat session by displaying information and
  # conversation history, then prompts the user for input to begin interacting
  # with the chat.
  def start
    info
    if messages.size > 1
      messages.list_conversation(2)
    end
    STDOUT.puts "\nType /help to display the chat help."

    interact_with_user
  end

  private

  # Handles user input commands and processes chat interactions.
  #
  # @param content [String] The input content to process
  # @return [Symbol, String, nil] Returns a symbol indicating next action,
  #   the content to be processed, or nil for no action needed
  def handle_input(content)
    case content
    when %r(^/reconnect)
      STDERR.print green { "Reconnecting to ollama #{base_url.to_s.inspect}…" }
      connect_ollama
      STDERR.puts green { " Done." }
      :next
    when %r(^/copy$)
      copy_to_clipboard
      :next
    when %r(^/paste$)
      paste_from_input
    when %r(^/markdown$)
      markdown.toggle
      :next
    when %r(^/stream$)
      stream.toggle
      :next
    when %r(^/location$)
      location.toggle
      :next
    when %r(^/voice(?:\s+(change))?$)
      if $1 == 'change'
        change_voice
      else
        voice.toggle
      end
      :next
    when %r(^/list(?:\s+(\d*))?$)
      n = 2 * $1.to_i if $1
      messages.list_conversation(n)
      :next
    when %r(^/last(?:\s+(\d*))?$)
      n = $1.to_i if $1
      messages.show_last(n)
      :next
    when %r(^/clear(?:\s+(messages|links|history|tags|all))?$)
      clean($1)
      :next
    when %r(^/clobber$)
      clean('all')
      :next
    when %r(^/drop(?:\s+(\d*))?$)
      messages.drop($1)
      messages.show_last
      :next
    when %r(^/model$)
      @model = choose_model('', @model)
      :next
    when %r(^/system(?:\s+(show))?$)
      if $1 != 'show'
        change_system_prompt(@system)
      end
      @messages.show_system_prompt
      :next
    when %r(^/prompt)
      @prefill_prompt = choose_prompt
      :next
    when %r(^/regenerate$)
      if content = messages.second_last&.content
        content.gsub!(/\nConsider these chunks for your answer.*\z/, '')
        messages.drop(1)
      else
        STDOUT.puts "Not enough messages in this conversation."
        return :redo
      end
      @parse_content = false
      content
    when %r(^/collection(?:\s+(clear|change))?$)
      case $1 || 'change'
      when 'clear'
        loop do
          tags = @documents.tags.add('[EXIT]').add('[ALL]')
          tag = OllamaChat::Utils::Chooser.choose(tags, prompt: 'Clear? %s')
          case tag
          when nil, '[EXIT]'
            STDOUT.puts "Exiting chooser."
            break
          when '[ALL]'
            if ask?(prompt: 'Are you sure? (y/n) ') =~ /\Ay/i
              @documents.clear
              STDOUT.puts "Cleared collection #{bold{@documents.collection}}."
              break
            else
              STDOUT.puts 'Cancelled.'
              sleep 3
            end
          when /./
            @documents.clear(tags: [ tag ])
            STDOUT.puts "Cleared tag #{tag} from collection #{bold{@documents.collection}}."
            sleep 3
          end
        end
      when 'change'
        choose_collection(@documents.collection)
      end
      :next
    when %r(^/info$)
      info
      :next
    when %r(^/document_policy$)
      document_policy.choose
      :next
    when %r(^/think$)
      think_mode.choose
      :next
    when %r(^/think_loud$)
      think_loud.toggle
      :next
    when %r(^/import\s+(.+))
      @parse_content = false
      import($1) or :next
    when %r(^/summarize\s+(?:(\d+)\s+)?(.+))
      @parse_content = false
      summarize($2, words: $1) or :next
    when %r(^/embedding$)
      embedding_paused.toggle(show: false)
      embedding.show
      :next
    when %r(^/embed\s+(.+))
      @parse_content = false
      embed($1) or :next
    when %r(^/web\s+(?:(\d+)\s+)?(.+))
      @parse_content = false
      web($1, $2)
    when %r(^/input(?:\s+(.+))?$)
      @parse_content = false
      input($1) or :next
    when %r(^/context(?:\s+(.+))?$)
      arg = $1
      arg and patterns = arg.scan(/(\S+)/).flatten
      @parse_content = false
      context_spook(patterns) or :next
    when %r(^/compose$)
      compose or :next
    when %r(^/revise_last$)
      revise_last
      :next
    when %r(^/save\s+(.+)$)
      save_conversation($1)
      :next
    when %r(^/links(?:\s+(clear))?$)
      manage_links($1)
      :next
    when %r(^/load\s+(.+)$)
      load_conversation($1)
      :next
    when %r(^/pipe\s+(.+)$)
      pipe($1)
      :next
    when %r(^/output\s+(.+)$)
      output($1)
      :next
    when %r(^/vim(?:\s+(.+))?$)
      if message = messages.last
        clientserver = config.vim?&.clientserver
        OllamaChat::Vim.new($1, clientserver:).insert message.content
      else
        STDERR.puts "Warning: No message found to insert into Vim"
      end
      :next
    when %r(^/tools(?:\s+(enable|disable))?$)
      case $1
      when nil
        list_tools
      when 'enable'
        enable_tool
      when 'disable'
        disable_tool
      end
      :next
    when %r(^/config$)
      display_config
      :next
    when %r(^/quit$), nil
      STDOUT.puts "Goodbye."
      :return
    when %r(^/)
      display_chat_help
      :next
    when /\A\s*\z/
      STDOUT.puts "Type /quit to quit."
      :next
    end
  end

  # Performs a web search and processes the results based on document processing configuration.
  #
  # Searches for the given query using the configured search engine and processes up to
  # the specified number of URLs. The processing approach varies based on the current
  # document policy and embedding status:
  #
  # - **Embedding mode**: When `document_policy.selected == 'embedding'` AND `@embedding.on?` is true,
  #   each result is embedded and the query is interpolated into the `web_embed` prompt.
  # - **Summarizing mode**: When `document_policy.selected == 'summarizing'`,
  #   each result is summarized and both query and results are interpolated into the
  #   `web_summarize` prompt.
  # - **Importing mode**: For all other cases, each result is imported and both query and
  #   results are interpolated into the `web_import` prompt.
  #
  # @param count [String] The maximum number of search results to process (defaults to 1)
  # @param query [String] The search query string
  #
  # @return [String, Symbol] The interpolated prompt content when successful,
  #   or :next if no URLs were found or processing failed
  #
  # @example Basic web search
  #   web('3', 'ruby programming tutorials')
  #
  # @example Web search with embedding policy
  #   # With document_policy.selected == 'embedding' and @embedding.on?
  #   # Processes results through embedding pipeline
  #
  # @example Web search with summarizing policy
  #   # With document_policy.selected == 'summarizing'
  #   # Processes results through summarization pipeline
  #
  # @see #search_web
  # @see #fetch_source
  # @see #embed_source
  # @see #import
  # @see #summarize
  def web(count, query)
    urls = search_web(query, count.to_i) or return :next
    if document_policy.selected == 'embedding' && @embedding.on?
      prompt = config.prompts.web_embed
      urls.each do |url|
        fetch_source(url) { |url_io| embed_source(url_io, url) }
      end
      prompt.named_placeholders_interpolate({query:})
    elsif document_policy.selected == 'summarizing'
      prompt = config.prompts.web_import
      results = urls.each_with_object('') do |url, content|
        summarize(url).full? do |c|
          content << c.ask_and_send_or_self(:read)
        end
      end
      prompt.named_placeholders_interpolate({query:, results:})
    else
      prompt = config.prompts.web_summarize
      results = urls.each_with_object('') do |url, content|
        import(url).full? do |c|
          content << c.ask_and_send_or_self(:read)
        end
      end
      prompt.named_placeholders_interpolate({query:, results:})
    end
  end

  # The manage_links method handles operations on a collection of links, such
  # as displaying them or clearing specific entries.
  #
  # It supports two main commands: 'clear' and nil (default).
  # When the command is 'clear', it presents an interactive menu to either
  # clear all links or individual links.
  # When the command is nil, it displays the current list of links with
  # hyperlinks.
  #
  # @param command [ String, nil ] the operation to perform on the links
  def manage_links(command)
    case command
    when 'clear'
      loop do
        links_options = links.dup.add('[EXIT]').add('[ALL]')
        link = OllamaChat::Utils::Chooser.choose(links_options, prompt: 'Clear? %s')
        case link
        when nil, '[EXIT]'
          STDOUT.puts "Exiting chooser."
          break
        when '[ALL]'
          if ask?(prompt: 'Are you sure? (y/n) ') =~ /\Ay/i
            links.clear
            STDOUT.puts "Cleared all links in list."
            break
          else
            STDOUT.puts 'Cancelled.'
            sleep 3
          end
        when /./
          links.delete(link)
          STDOUT.puts "Cleared link from links in list."
          sleep 3
        end
      end
    when nil
      if links.empty?
        STDOUT.puts "List is empty."
      else
        Math.log10(links.size).ceil
        format  = "% #{}s. %s"
        connect = -> link { hyperlink(link) { link } }
        STDOUT.puts links.each_with_index.map { |x, i| format % [ i + 1, connect.(x) ] }
      end
    end
  end

  # The clean method clears various parts of the chat session based on the
  # specified parameter.
  #
  # @param what [ String, nil ] the type of data to clear, defaults to
  #   'messages' if nil
  def clean(what)
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
    when 'all'
      if ask?(prompt: 'Are you sure to clear messages and collection? (y/n) ') =~ /\Ay/i
        messages.clear
        @documents.clear
        links.clear
        clear_history
        STDOUT.puts "Cleared messages and collection #{bold{@documents.collection}}."
      else
        STDOUT.puts 'Cancelled.'
      end
    end
  end

  # The display_config method renders the configuration and displays it using a
  # pager.
  # It determines an appropriate pager command based on environment variables
  # and available system commands, then uses Kramdown::ANSI::Pager to show the
  # formatted configuration output.
  def display_config
    command  = OllamaChat::EnvConfig::PAGER?
    rendered = config.to_s
    Kramdown::ANSI::Pager.pager(
      lines: rendered.count(?\n),
      command:
    ) do |output|
      output.puts rendered
    end
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
      @parse_content = true
      type           = :terminal_input
      input_prompt   = bold { color(172) { message_type(@images) + " user" } } + bold { "> " }
      begin
        if content = handle_tool_call_results?
          @parse_content = false
        else
          content = enable_command_completion do
            if prefill_prompt = @prefill_prompt.full?
              Reline.pre_input_hook = -> {
                Reline.insert_text prefill_prompt.gsub(/\n*\z/, '')
                @prefill_prompt = nil
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

      content = content.encode(invalid: :replace)

      content, tags = if @parse_content
                        parse_content(content, @images)
                      else
                        [ content, Documentrix::Utils::Tags.new(valid_tag: /\A#*([\w\]\[]+)/) ]
                      end

      if embedding.on? && content
        records = @documents.find_where(
          content.downcase,
          tags:,
          prompt:     config.embedding.model.prompt?,
          text_size:  config.embedding.found_texts_size?,
          text_count: config.embedding.found_texts_count?,
        )
        unless records.empty?
          content += "\nConsider these chunks for your answer:\n\n"\
            "#{records.map { [ _1.text, _1.tags_set ] * ?\n }.join("\n\n---\n\n")}"
        end
      end

      messages << Ollama::Message.new(role: 'user', content:, images: @images.dup)
      @images.clear
      handler = OllamaChat::FollowChat.new(
        chat:     self,
        messages:,
        voice:    (@voices.selected if voice.on?)
      )
      begin
        retried = false
        ollama.chat(
          model:    @model,
          messages: ,
          options:  @model_options,
          stream:   stream.on?,
          think:    ,
          tools:    ,
          &handler
        )
      rescue Ollama::Errors::BadRequestError
        if think? && !retried
          STDOUT.puts "#{bold('Error')}: in think mode, switch thinking off and retry."
          sleep 1
          think_mode.selected  = 'disabled'
          retried = true
          retry
        else
          raise
        end
      end
      if embedding.on? && !records.empty?
        STDOUT.puts "", records.map { |record|
          link = if record.source =~ %r(\Ahttps?://)
                   record.source
                 else
                   'file://%s' % File.expand_path(record.source)
                 end
          [ link, ?# + record.tags.first ]
        }.uniq.map { |l, t| hyperlink(l, t) }.join(' ')
        debug and jj messages.to_ary
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
      STDOUT.puts "#{bold('Error')}: Currently lost connection to ollama server and cannot send command."
    rescue Interrupt
      STDOUT.puts "Type /quit to quit."
    ensure
        self.server_socket_message = nil
    end
    0
  rescue ComplexConfig::AttributeMissing, ComplexConfig::ConfigurationSyntaxError => e
    fix_config(e)
  ensure
    save_history
  end

  private

  # The base_url method returns the Ollama server URL from command-line options
  # or environment configuration.
  #
  # @return [String] the base URL used for connecting to the Ollama API
  def base_url
    @opts[?u] || OllamaChat::EnvConfig::OLLAMA::URL
  end

  # The connect_ollama method establishes a connection to the Ollama API server.
  #
  # This method initializes a new Ollama::Client instance with configured timeouts
  # and connection parameters, then verifies that the connected server meets
  # the minimum required API version (0.9.0). It sets the @ollama instance
  # variable to the configured client and stores the server version in @server_version.
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
      pull_model_unless_present(@embedding_model, @embedding_model_options)
      collection = @opts[?C] || config.embedding.collection
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
  #
  # @see fetch_source
  # @see embed_source
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

  # The fix_config method handles configuration file errors by informing the
  # user about the exception and prompting them to fix it.
  # It then executes a diff tool to compare the current config file with the
  # default one.
  # This method exits the program after handling the configuration error
  #
  # @param exception [ Exception ] the exception that occurred while reading
  #   the config file
  def fix_config(exception)
    save_conversation('backup.json')
    STDOUT.puts "When reading the config file, a #{exception.class} "\
      "exception was caught: #{exception.message.inspect}"
    unless diff_tool = OllamaChat::EnvConfig::DIFF_TOOL?
      exit 1
    end
    if ask?(prompt: 'Do you want to fix the config? (y/n) ') =~ /\Ay/i
      system Shellwords.join([
        diff_tool,
        @ollama_chat_config.filename,
        @ollama_chat_config.default_config_path,
      ])
      exit 0
    else
      exit 1
    end
  end

  # Enables tab completion for chat commands within the interactive session
  #
  # Temporarily replaces the current Reline completion procedure with a custom
  # one that provides command completion based on the chat help message.
  #
  # @param block [Proc] The block to execute with enhanced tab completion enabled
  #
  # @return [Object] The return value of the executed block
  #
  # @see display_chat_help_message
  # @see Reline.completion_proc
  def enable_command_completion(&block)
    old = Reline.completion_proc
    commands = display_chat_help_message.scan(/^\s*(\S+)/).inject(&:concat)
    Reline.completion_proc = -> input {
      commands.grep Regexp.new('\A' + Regexp.quote(input))
    }
    block.()
  ensure
    Reline.completion_proc = old
  end
end
