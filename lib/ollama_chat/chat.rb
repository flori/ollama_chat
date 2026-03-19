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
    @opts               = go 'f:u:m:s:p:c:C:D:MESVh', argv
    @opts[?h] and exit usage
    @opts[?V] and exit version
    @messages           = OllamaChat::MessageList.new(self)
    @ollama_chat_config = OllamaChat::OllamaChatConfig.new(@opts[?f])
    self.config         = @ollama_chat_config.config
    setup_switches(config)
    setup_state_selectors(config)
    connect_ollama
    if conversation_file = @opts[?c]
      messages.load_conversation(conversation_file)
    elsif backup_file = OC::XDG_CACHE_HOME + 'backup.json' and backup_file.exist?
      messages.load_conversation(backup_file)
      FileUtils.rm_f backup_file
    else
      @setup_system_prompt = true
    end
    embedding_enabled.set(config.embedding.enabled && !@opts[?E])
    @documents            = setup_documents
    @cache                = setup_cache
    @images               = []
    @kramdown_ansi_styles = configure_kramdown_ansi_styles
    @enabled_tools        = default_enabled_tools
    @tool_call_results    = {}
    init_chat_history
    setup_personae_directory
    @opts[?S] and init_server_socket
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

  # Provides read-only access to the cache instance used by the object
  #
  # @attr_reader [Cache] the cache instance
  attr_reader :cache

  # The start method initializes the chat session by displaying information,
  # then prompts the user for input to begin interacting with the chat.
  def start
    begin
      use_model(@opts[?m].full? || config.model.name)
    rescue OllamaChat::UnknownModelError => e
      abort "Failed to use to model: #{e}"
    end
    @model_options  = Ollama::Options[config.model.options]

    @setup_system_prompt and setup_system_prompt

    STDOUT.puts "\nType /help to display the chat help."

    interact_with_user
  end

  # The debug method accesses the debug configuration setting.
  #
  # @return [TrueClass, FalseClass] the current debug mode status
  def debug
    OC::OLLAMA::CHAT::DEBUG
  end

  private

  # Removes lines that are JSON objects containing the given key.
  #
  # @param name [String, Symbol] key to look for in each line
  # @param content [String] multiline text that may contain internal JSON markers
  # @return [String] text with matching marker lines removed
  def strip_internal_json_markers(name, content)
    name = name.to_s
    content.each_line.map do |line|
      JSON(line).fetch(name) and next
    rescue
      line
    end.compact.join
  end

  # The disable_content_parsing method turns off content parsing by setting
  # `@parse_content` to false.
  #
  # This prevents automatic parsing of user input content during chat
  # processing.
  def disable_content_parsing
    @parse_content = false
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
    regexp: %r(^/toggle(?:\s+(markdown|stream|location|runtime_info|voice|think_loud))?$),
    complete: [ 'toggle', %w[ markdown stream location runtime_info voice think_loud embedding ] ],
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
    name: :model,
    regexp: %r(^/model$),
    help: 'change the model'
  ) do
    begin
      use_model
    rescue OllamaChatError::UnknownModelError => e
      msg = "Caught #{e.class}: #{e}"
      log(:error, msg, warn: true)
    end
    :next
  end

  command(
    name: :system,
    regexp: %r(^/system(?:\s+(change))?$),
    complete: [ 'system', %w[ change ] ],
    optional: true,
    help: 'change/show system prompt'
  ) do |subcommand|
    if subcommand == 'change'
      change_system_prompt(@system)
    end
    @messages.show_system_prompt
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
    help: 'clear these records'
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
    help: 'display (or clear) links used in the chat',
  ) do |subcommand|
    manage_links(subcommand)
    :next
  end

  command(
    name: :revise,
    regexp: %r(^/revise(?:\s+(edit))?$),
    complete: [ 'revise', %w[ edit ] ],
    help: 'revise the last message (and/or edit the query)'
  ) do |subcommand|
    if content = messages.second_last&.content
      content = strip_internal_json_markers(:ollama_chat_retrieval_snippets, content)
      content = strip_internal_json_markers(:ollama_chat_runtime_information, content)
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
    regexp: %r(^/prompt),
    help: 'prefill user prompt with preset prompts',
  ) do
    @prefill_prompt = choose_prompt
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
    name: :save,
    regexp: %r(^/save\s+(.+)$),
    options: 'path',
    help: 'store conversation messages'
  ) do |path|
    save_conversation(path)
    :next
  end

  command(
    name: :load,
    regexp: %r(^/load\s+(.+)$),
    options: 'path',
    help: 'load conversation messages'
  ) do |path|
    load_conversation(path)
    :next
  end

  ## Collection

  command(
    name: :collection,
    regexp: %r(^/collection(?:\s+(clear|change))?$),
    complete: [ 'collection', %w[ clear change ] ],
    help: 'change (default) collection or clear'
  ) do |subcommand|
    case subcommand || 'change'
    when 'clear'
      loop do
        tags = @documents.tags.add('[EXIT]').add('[ALL]')
        tag = OllamaChat::Utils::Chooser.choose(tags, prompt: 'Clear? %s')
        case tag
        when nil, '[EXIT]'
          STDOUT.puts "Exiting chooser."
          break
        when '[ALL]'
          if confirm?(prompt: 'Are you sure? (y/n) ') =~ /y/i
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
  end

  ## Persona

  command(
    name: :persona,
    regexp: %r(^/persona(?:\s+(add|delete|edit|file|info|list|load|play))?$),
    complete: [ 'persona', %w[ add delete edit file info list load play ] ],
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
      if result = delete_persona
        result
      else
        :next
      end
    when 'edit'
      if result = edit_persona and
          confirm?(prompt: 'Load new persona profile? (y/n) ') =~ /y/i
        then
        result
      else
        :next
      end
    when 'file'
      if pathname = choose_filename('**/*.md')
        pathname.read
      else
        :next
      end
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
    when 'play'
      if pathname = choose_filename('**/*.md')
        play_persona_file(pathname)
      else
        :next
      end
    else
      if result = play_persona.full?
        result
      else
        :next
      end
    end
  end

  ## Input

  command(
    name: :compose,
    regexp: %r(^/compose$),
    help: 'compose content using an EDITOR'
  ) do
    compose or :next
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
    regexp: %r(^/input(?:\s+(path|summary|context|embedding)(?:\s*(?=\z))?)?((?:\s+-(?:[ad]|w\s*\d+))*)(?:\s+(pattern))?(?:\s+(.+))?$),
    optional: true,
    complete: [ 'input', [ 'path', 'summary', 'context', 'embedding', '', ], [ 'pattern', '' ] ],
    options: '[-w|-a] [arg…]',
    help: <<~EOT
      Read content from files, URLs, or glob patterns
      and optionally transform it.
      Use subcommands: context, embedding, path, summary,
        import (the default).
      Use pattern mode for local files.
      Options:
        -w <words> (summary subcommand only, default 100)
        -a (pattern mode only, include all files for patterns)
    EOT
  ) do |input_mode,opt,pattern_mode,arg|
    disable_content_parsing
    case input_mode
    when 'summary'
      if pattern_mode
        opts  = go_command('aw:', opt)
        words = opts.fetch(?w, 100)
        all   = opts.fetch(?a, false)
        arg and patterns = arg.scan(/(\S+)/).flatten
        next provide_file_set_content(patterns, all:) { summarize(_1, words:) } || :next
      elsif arg
        words  = go_command('w:', opt).fetch(?w, 100)
        source = arg
        next summarize(source, words:) || :next
      else
        STDERR.puts "Need a source to summarize for input!"
        next :next
      end
    when 'context'
      if pattern_mode
        all      = go_command('a', opt).fetch(?a, false)
        patterns = arg&.scan(/(\S+)/)&.flatten.full? || [ '**/*' ]
        next context_spook(patterns, all:) || :next
      elsif arg
        next context_spook(Array(arg.to_s), all: true) || :next
      else
        next context_spook(nil) || :next
      end
    when 'embedding'
      if pattern_mode
        all = go_command('a', opt).fetch(?a, false)
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
      if pattern_mode
        all = go_command('a', opt).fetch(?a, false)
        arg and patterns = arg.scan(/(\S+)/).flatten
        next provide_file_set_content(patterns, all:, &:read) || :next
      elsif arg
        filename = Pathname.new(arg).expand_path
        next filename.file? && filename.read || :next
      else
        STDERR.puts "Need a filename to read for input!"
        next :next
      end
    else
      if pattern_mode
        all = go_command('a', opt).fetch(?a, false)
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
    regexp: %r(^/info$),
    help: 'show information for current session',
  ) do
    info
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
    config.prompts.help % { commands: help_message }
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
          if confirm?(prompt: 'Are you sure? (y/n) ') =~ /y/i
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
        w       = Math.log10(links.size + 1).ceil
        format  = "%#{w}s. %s"
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
    persona_profile = nil
    case what
    when 'messages', nil
      messages.clear
      persona_profile = reload_default_persona
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
      if confirm?(prompt: 'Are you sure to clear messages and collection? (y/n) ') =~ /y/i
        messages.clear
        @documents.clear
        links.clear
        clear_history
        persona_profile = reload_default_persona
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
      if persona_result = setup_persona_from_opts
        disable_content_parsing
        content = persona_result
      else
        @parse_content = true
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
      end

      content = content.encode(invalid: :replace)

      content, tags = if @parse_content
                        parse_content(content, @images)
                      else
                        [ content, Documentrix::Utils::Tags.new(valid_tag: /\A#*([\w\]\[]+)/) ]
                      end

      if embedding.on? && content
        records = @documents.find_where(
          content.downcase.first(config.embedding.model.context_length),
          tags:,
          prompt:     config.embedding.model.prompt?,
          text_size:  config.embedding.found_texts_size?,
          text_count: config.embedding.found_texts_count?,
        )
        unless records.empty?
          content << ?\n << JSON(
            prompt: "Consider these snippets generated from retrieval when formulating your response!",
            ollama_chat_retrieval_snippets: records.map { |r|
              {
                text: r.text,
                tags: r.tags_set.map { |t| { name: t.to_s(link: false), source: t.source }.compact }
              }
            },
          )
        end
      end

      runtime_info.on? && content and
        content << ?\n << {
          ollama_chat_runtime_information: runtime_information
        }.to_json

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

  # Sets up the system prompt for the chat session.
  #
  # This method determines whether to use a default system prompt or a custom
  # one specified via command-line options. If a custom system prompt is
  # provided with a regexp selector (starting with ?), it invokes the
  # change_system_prompt method to handle the selection. Otherwise, it
  # retrieves the system prompt from a file or uses the default value, then
  # sets it in the message history.
  def setup_system_prompt
    default = config.system_prompts.default? || @model_metadata.system
    if @opts[?s] =~ /\A\?/
      change_system_prompt(default, system: @opts[?s])
    else
      system = OllamaChat::Utils::FileArgument.get_file_argument(@opts[?s], default:)
      system.present? and messages.set_system_prompt(system)
    end
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
