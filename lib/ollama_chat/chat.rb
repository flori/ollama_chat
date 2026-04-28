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
  include OllamaChat::HTTPHandling
  include OllamaChat::CommandConcern
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
  include OllamaChat::Utils::ValueFormatter

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
    init_chat_history
    setup_personae_directory
    @opts[?S] and init_server_socket
  rescue ComplexConfig::AttributeMissing, ComplexConfig::ConfigurationSyntaxError => e
    fix_config(e)
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

  private

  # The generate method sends a prompt to the Ollama model and returns the
  # result.
  #
  # @param prompt [ String ] the prompt to send to the model
  #
  # @return [ Ollama::Response ] the response from the Ollama model
  def generate(prompt:)
    prepare_model(@model)
    ollama.generate(
      model: @model,
      prompt:,
      options: model_options,
      stream: false,
      think: false,
    )
  end

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

  # Chat commands

  ## Clipboard

  command(
    name: :copy,
    regexp: %r(/copy$),
    help: 'to copy last response to clipboard'
  ) do
    copy_to_clipboard
    :next
  end

  command(
    name: :paste,
    regexp: %r(^/paste$),
    help: 'to paste content from the clipboard'
  ) do
    disable_content_parsing
    paste_from_clipboard
  end

  ## Settings

  command(
    name: :config,
    regexp: %r(^/config(?:\s+(edit|reload))?$),
    complete: [ 'config', %w[ edit reload ] ],
    optional: true,
    help: 'output/edit/reload configuration'
  ) do |subcommand|
    case subcommand
    when 'edit'
      edit_config
    when 'reload'
      reload_config
    else
      display_config
    end
    :next
  end

  command(
    name: :document_policy,
    regexp: %r(^/document_policy$),
    help: 'pick a scan policy for documents'
  ) do
    document_policy.choose
    :next
  end

  command(
    name: :toggle,
    regexp: %r(^/toggle(?:\s+(markdown|stream|location|runtime_info|voice|think_loud|think_strip))?$),
    complete: [ 'toggle', %w[ markdown stream location runtime_info voice think_loud think_strip embedding ] ],
    help: 'toggle switch'
  ) do |toggle_name|
    if toggle_name
      send(toggle_name).toggle
    else
      STDOUT.puts "Available toggles: markdown|stream|location|runtime_info|voice|think_loud|embedding"
    end
    :next
  end

  command(
    name: :toggle_embedding,
    regexp: %r(^/toggle\s+embedding$),
    complete: [],
    help: nil
  ) do
    embedding_paused.toggle(show: false)
    embedding.show
    :next
  end

  command(
    name: :favourite,
    regexp: %r(^/favourite(?:\s+(add|delete))?(?:\s+(model|prompt|system_prompt|persona))?$),
    complete: [ 'favourite', %w[ add delete ], %w[ model prompt system_prompt persona ] ],
    help: 'manage model, prompt, system_prompt, persona favourites'
  ) do |subcommand, type|
    case subcommand
    when 'add'
      add_favourite(type)
    when 'delete'
      delete_favourite(type)
    end
    :next
  end

  command(
    name: :model,
    regexp: %r(^/model(?:\s+(change|options|options from session|options to session))$),
    complete: [ 'model', %w[ change options options\ from\ session options\ to\ session ] ],
    help: 'change the model/model options/sync with session model options'
  ) do |subcommand|
    case subcommand
    when 'change'
      begin
        use_model
      rescue OllamaChat::UnknownModelError => e
        msg = "Caught #{e.class}: #{e}"
        log(:error, msg, warn: true)
      end
    when 'options'
      edit_model_options(@model)
    when 'options from session'
      copy_model_options_from_session
    when 'options to session'
      copy_model_options_to_session
    end
    :next
  end

  command(
    name: :system,
    regexp: %r(^/system(?:\s+(add|delete|edit|list|change|duplicate|export|import))?(?:\s+(\S+))?$),
    complete: [ 'system', %w[ add delete edit list change duplicate export import ] ],
    optional: true,
    help: 'change/show/manage system prompt'
  ) do |subcommand, filename|
    case subcommand
    when 'add'
      add_new_system_prompt and @messages.show_system_prompt
    when 'delete'
      choose_and_delete_system_prompt
    when 'edit'
      choose_and_edit_system_prompt
    when 'list'
      list_system_prompts
    when 'change'
      change_system_prompt(@system)
      @messages.show_system_prompt
    when 'duplicate'
      duplicate_system_prompt
    when 'import'
      import_system_prompt(filename)
    when 'export'
      export_system_prompt
    when nil
      @messages.show_system_prompt
    end
    :next
  end

  command(
    name: :think,
    regexp: %r(^/think$),
    help: 'choose ollama think mode setting for models'
  ) do
    think_mode.choose
    :next
  end

  command(
    name: :tools,
    regexp: %r(^/tools(?:\s+(enable|disable|on|off))?),
    complete: [ 'tools', %w[ enable disable on off ] ],
    optional: true,
    help: "list enabled, enable/disable tools,\nsupport on/off"
  ) do |subcommand|
    case subcommand
    when nil
      list_tools
    when 'enable'
      enable_tool
    when 'disable'
      disable_tool
    when 'on'
      tools_support.set(true, show: true)
    when 'off'
      tools_support.set(false, show: true)
    end
    :next
  end

  command(
    name: :voice,
    regexp: %r(^/voice$),
    help: 'change the voice'
  ) do
    change_voice
    :next
  end

  ## Session

  command(
    name: :session,
    regexp: %r(^/session(?:\s+(list|new|duplicate|rename|summarize|change|delete|model options))?((?:\s+-(?:[sf]))*)(?:\s+(.+))?$),
    complete: [ 'session', %w[ list new duplicate rename summarize change delete model\ options ] ],
    optional: true,
    options: '[-c|-f] [name]',
    help: <<~EOT,
      Show session list, create new/duplicate, rename, summarize (-s
      sentence/-f for markdown file output), change, delete session, edit
      session model options
    EOT
  ) do |subcommand, opts, name|
    case subcommand
    when nil
      show_session
    when 'list'
      list_sessions
    when 'new'
      set_new_session
    when 'duplicate'
      duplicate_session
    when 'delete'
      delete_session
    when 'rename'
      rename_session
    when 'summarize'
      opts = go_command('fs', opts)
      if summary = summarize_session(pretty: true, sentence: opts[?s]).full?
        if opts[?f] and filename = ask?(prompt: "❓ Enter filename: ").full? { Pathname.new(_1) }
          if filename.exist? && !confirm?(
              prompt: "🔔 File #{filename.to_s.inspect} already exists, overwrite? (y/n) ",
              yes: /\Ay/i
          )
            then
            STDERR.puts "File not written!"
            next :next
          end
          filename.write(summary)
          STDERR.puts "File successfully written."
        else
          use_pager do |output|
            output.puts kramdown_ansi_parse(summary)
          end
        end
      end
    when 'change'
      change_session(name)
    when 'model options'
      edit_session_model_options
    end
    :next
  end

  ## Conversation

  command(
    name: :list,
    regexp: %r(^/list(?:\s+(\d*))?$),
    options: '[n=1]',
    help: 'list the last n / all conversation exchanges'
  ) do
    n = 2 * _1.to_i if _1
    messages.list_conversation(n)
    :next
  end

  command(
    name: :last,
    regexp: %r(^/last(?:\s+(\d*))?$),
    options: '[n=1]',
    help: 'show the last n / 1 system/assistant message'
  ) do
    n = _1.to_i.clamp(1..)
    messages.show_last(n)
    :next
  end

  command(
    name: :drop,
    regexp: %r(^/drop(?:\s+(\d*))?$),
    options: '[n=1]',
    help: 'drop the last n exchanges, defaults to 1'
  ) do
    messages.drop(_1)
    messages.show_last
    :next
  end

  command(
    name: :clear,
    regexp: %r(^/clear(?:\s+(messages|links|history|tags|all))?$),
    complete: [ 'clear', %w[ messages links history tags all ] ],
    optional: true,
    help: 'clear these records, messages without argument'
  ) do |subcommand|
    if result = clean(subcommand)
      disable_content_parsing
      result
    else
      :next
    end
  end

  command(
    name: :links,
    regexp: %r(^/links(?:\s+(clear))?$),
    complete: [ 'links', %w[ clear ] ],
    optional: true,
    help: 'display (or clear) links used in the chat',
  ) do |subcommand|
    manage_links(subcommand)
    :next
  end

  command(
    name: :revise,
    regexp: %r(^/revise(?:\s+(edit))?$),
    complete: [ 'revise', %w[ edit ] ],
    optional: true,
    help: 'revise the last message (and/or edit the query)'
  ) do |subcommand|
    if message = messages.second_last
      content = message.stripped_content
      messages.drop(1)
      if subcommand == 'edit'
        content = edit_text(content)
      end
    else
      STDOUT.puts "Not enough messages in this conversation."
      next :redo
    end
    disable_content_parsing
    content
  end

  command(
    name: :prompt,
    regexp: %r(^/prompt(?:\s+(add|delete|edit|list|duplicate|import|export))?(?:\s+(\S+))?$),
    complete: [ 'prompt', %w[ add delete edit list duplicate import export ] ],
    optional: true,
    help: 'prefill user prompt with preset prompts, manage prompts',
  ) do |subcommand, filename|
    case subcommand
    when 'add'
      add_new_prompt
    when 'delete'
      choose_and_delete_prompt
    when 'edit'
      choose_and_edit_prompt
    when 'list'
      list_prompts
    when 'duplicate'
      duplicate_prompt
    when 'import'
      import_prompt(filename)
    when 'export'
      export_prompt
    when nil
      @prefill_prompt = choose_prompt&.to_s
    end
    :next
  end

  command(
    name: :change_response,
    regexp: %r(^/change_response$),
    help: 'edit the last response in EDITOR',
  ) do
    change_response
    :next
  end

  command(
    name: :conversation,
    regexp: %r(^/conversation\s+(save|load)\s+(.+)$),
    complete: [ 'conversation', %w[ save load ] ],
    help: 'manage conversations (save/load)'
  ) do |subcommand, path|
    case subcommand
    when 'save'
      save_conversation(path)
    when 'load'
      load_conversation(path)
    end
    :next
  end

  ## Collection

  command(
    name: :collection,
    regexp: %r(^/collection(?:\s+(clear|change|list|rename))?$),
    complete: [ 'collection', %w[ clear change list rename ] ],
    optional: true,
    help: 'display, clear (current), change, list, or rename collection'
  ) do |subcommand|
    case subcommand
    when 'clear'
      clear_collection
    when 'change'
      choose_collection(@documents.collection)
    when 'list'
      list_collections
    when 'rename'
      rename_collection(@documents.collection)
    when nil
      collection_stats
    end
    :next
  end

  ## Persona

  command(
    name: :persona,
    regexp: %r(^/persona(?:\s+(add|delete|edit|backup|import|export|duplicate|info|list|load))?$),
    complete: [ 'persona', %w[ add delete edit backup import export duplicate info list load ] ],
    optional: true,
    help: 'manage and load/play personae for roleplay',
  ) do |subcommand|
    disable_content_parsing
    case subcommand
    when 'add'
      if result = add_persona
        result
      else
        :next
      end
    when 'delete'
      delete_persona
      :next
    when 'edit'
      edit_persona
      :next
    when 'backup'
      backup_persona
      :next
    when 'duplicate'
      duplicate_persona_prompt
      :next
    when 'import'
      filename = choose_filename('**/*.md')
      if filename and name = import_persona_prompt(filename)
        STDOUT.puts "Imported person as #{name.inspect}."
      end
      :next
    when 'export'
      export_persona_prompt
      :next
    when 'info'
      info_persona
      :next
    when 'list'
      list_personae
      :next
    when 'load'
      if result = load_personae
        result
      else
        :next
      end
    else
      set_default_persona
      :next
    end
  end

  ## Input

  command(
    name: :compose,
    regexp: %r(^/compose$),
    help: 'compose content using an EDITOR'
  ) do
    edit_text.full? or :next
  end

  command(
    name: :web,
    regexp: %r(^/web\s+(?:(\d+)\s+)?(.+)),
    options: '[number=1] query',
    help: 'query web for so many results'
  ) do |count, query|
    disable_content_parsing
    web(count, query)
  end

  command(
    name: :input,
    regexp: %r(^/input(?:\s+(path|summary|context|embedding)(?:\s*(?=\z))?)?((?:\s+-(?:[ap]|w\s*\d+))*)(?:\s+(.+))?$),
    optional: true,
    complete: [ 'input', [ 'path', 'summary', 'context', 'embedding', '', ] ],
    options: '[-w|-a|-p] [arg…]',
    help: <<~EOT
      Read content from files, URLs, or glob patterns
      and optionally transform it.
      Use subcommands: context, embedding, path, summary,
        import (the default).
      Options:
        -w <words> (summary subcommand only, default 100)
        -a (pattern mode only, include all files for patterns)
    EOT
  ) do |input_mode,opts,arg|
    disable_content_parsing
    case input_mode
    when 'summary'
      opts = go_command('paw:', opts)
      if opts[?p]
        words = opts.fetch(?w, 100)
        all   = opts.fetch(?a, false)
        arg and patterns = arg.scan(/(\S+)/).flatten
        next provide_file_set_content(patterns, all:) { summarize(_1, words:) } || :next
      elsif arg
        words = opts.fetch(?w, 100)
        source = arg
        next summarize(source, words:) || :next
      else
        STDERR.puts "Need a source to summarize for input!"
        next :next
      end
    when 'context'
      opts = go_command('pa', opts)
      if opts[?p]
        all      = opts.fetch(?a, false)
        patterns = arg&.scan(/(\S+)/)&.flatten.full? || [ '**/*' ]
        next context_spook(patterns, all:) || :next
      elsif arg
        next context_spook(Array(arg.to_s), all: true) || :next
      else
        next context_spook(nil) || :next
      end
    when 'embedding'
      opts = go_command('pa', opts)
      if opts[?p]
        all = opts.fetch(?a, false)
        arg and patterns = arg.scan(/(\S+)/).flatten
        next provide_file_set_content(patterns, all:) { embed(_1) } || :next
      elsif arg
        source = arg
        next embed(source) || :next
      else
        STDERR.puts "Need a source to embed for input!"
        next :next
      end
    when 'path'
      opts = go_command('pa', opts)
      if opts[?p]
        all = opts.fetch(?a, false)
        arg and patterns = arg.scan(/(\S+)/).flatten
        read = -> pathname {
          STDOUT.puts "Reading #{pathname.to_s.inspect}."
          pathname.read
        }
        next provide_file_set_content(patterns, all:, &read) || :next
      elsif arg
        filename = Pathname.new(arg).expand_path
        next filename.file? && filename.read || :next
      else
        STDERR.puts "Need a filename to read for input!"
        next :next
      end
    else
      opts = go_command('pa', opts)
      if opts[?p]
        all = opts.fetch(?a, false)
        arg and patterns = arg.scan(/(\S+)/).flatten
        next provide_file_set_content(patterns, all:) { import(_1) } || :next
      elsif arg
        source = arg
        next import(source) || :next
      else
        STDERR.puts "Need a source to import for input!"
        next :next
      end
    end
  end

  ## Output

  command(
    name: :pipe,
    regexp: %r(^/pipe\s+(.+)$),
    options: 'path',
    help: "write last response to command's stdin",
  ) do |command|
    pipe(command)
    :next
  end

  command(
    name: :vim,
    regexp: %r(^/vim(?:\s+(.+))?$),
    help: 'insert the last message into a vim (server)'
  ) do |servername|
    if message = messages.last
      vim(servername).insert message.content
    else
      STDERR.puts "Warning: No message found to insert into Vim"
    end
    :next
  end

  command(
    name: :output,
    regexp: %r(^/output\s+(.+)$),
    options: 'path',
    help: 'save last response to path',
  ) do |path|
    output(path)
    :next
  end

  ## Actions

  command(
    name: :reconnect,
    regexp: %r(^/reconnect$),
    help: 'reconnect to current ollama server'
  ) do
    STDERR.print green { "Reconnecting to ollama #{base_url.to_s.inspect}…" }
    connect_ollama
    STDERR.puts green { " Done." }
    :next
  end

  command(
    name: :quit,
    regexp: %r(^/(?:quit|exit)$),
    complete: [ %w[ quit exit ] ],
    help: 'quit/exit the application',
  ) do
    STDOUT.puts "Goodbye."
    :return
  end

  ## Information

  command(
    name: :info,
    regexp: %r(^/info(?:\s+(session|model|runtime|rag))?$),
    complete: [ 'info', %w[ session model runtime rag ] ],
    optional: true,
    help: 'show information for ollama_chat',
  ) do |subcommand|
    use_pager do |output|
      case subcommand
      when 'session'
        info_session(output:)
      when 'model'
        info_model(output:)
      when 'runtime'
        info_runtime(output:)
      when 'rag'
        info_rag(output:)
      else
        info(output:)
      end
    end
    :next
  end

  command(
    name: :help,
    regexp: %r(^/help me$),
    optional: true,
    complete: [ 'help', %w[ me ] ],
    help: 'to view this help (me=interactive ai help)'
  ) do
    disable_content_parsing
    prompt(:help).to_s % { commands: help_message }
  end

  command(
    name: :help_fallback,
    regexp: %r(^/),
    complete: []
  ) do
    display_chat_help
    :next
  end

  command(
    name: :type_quit,
    regexp: nil,
    complete: [],
  ) do
    STDOUT.puts "Type /quit to quit."
    :next
  end

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
    when 'all'
      if confirm?(prompt: '🔔 Are you sure to clear messages and collection? (y/n) ', yes: /\Ay/i)
        messages.clear
        @documents.clear
        links.clear
        clear_history
        STDOUT.puts "Cleared messages and collection #{bold{@documents.collection}}."
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
      enable_content_parsing
      type           = :terminal_input
      input_prompt   = bold { color(172) { message_type(@images) + " user" } } + bold { "> " }
      begin
        if content = handle_tool_call_results?
          disable_content_parsing
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

      parse_content? and content = parse_content(content, @images)

      runtime_info.on? && content and
        content << ?\n << {
          ollama_chat_runtime_information: runtime_information
        }.to_json

      messages << OllamaChat::Message.new(role: 'user', content:, images: @images.dup)
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
    save_history
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
