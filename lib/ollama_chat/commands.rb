require 'ollama_chat/command_concern'

# Namespace for all available slash commands within the Ollama Chat
# application.
#
# This module acts as a central repository where various functional commands
# are declared using the DSL provided by {OllamaChat::CommandConcern}. Each
# command definition includes a unique name, a triggering regular expression,
# and a help string for documentation.
#
# The commands are categorized into several areas:
# - Clipboard management (/copy, /paste)
# - Application settings (/config, /document policy, /toggle)
# - Model & System Prompt configuration (/model, /system, /think)
# - Tooling support (/tools)
# - Session management (/session)
# - Conversation history and manipulation (/list, /last, /drop, /clear, /regenerate)
# - RAG collection management (/collection)
# - Persona & Character roleplay (/persona, /character)
# - Input/Output operations (/compose, /web, /input, /pipe, /vim, /output)
# - System actions and info (/reconnect, /quit, /info, /help)
module OllamaChat::Commands
  include OllamaChat::CommandConcern

  ## Clipboard

  command(
    name: :copy,
    regexp: %r(^/copy(\s+-e)?\s*$),
    help: <<~EOT
      📋 Copy the last response to the clipboard.
         Options: -e to edit before copying.
    EOT
  ) do |opts|
    opts = go_command('e', opts)
    copy_to_clipboard(edit: opts[?e])
    :next
  end

  command(
    name: :paste,
    regexp: %r(^/paste(\s+-e)?\s*$),
    help: <<~EOT
      📋 Paste content from the clipboard.
         Options: -e to edit after pasting.
    EOT
  ) do |opts|
    disable_content_parsing
    opts = go_command('e', opts)
    paste_from_clipboard(edit: opts[?e])
  end

  ## Settings

  command(
    name: :config,
    regexp: %r(^/config(?:\s+(edit|reload))?$),
    complete: [ 'config', %w[ edit reload ] ],
    optional: true,
    help: <<~EOT
      ⚙️ View, edit, or reload configuration
    EOT
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
    regexp: %r(^/document policy$),
    complete: %w[ document policy ],
    help: <<~EOT
      📜 Select a scanning policy for documents
    EOT
  ) do
    document_policy.choose
    :next
  end

  command(
    name: :toggle,
    regexp: %r(^/toggle(?:\s+(markdown|stream|location|runtime_info|voice|think_loud|think_strip|embedding))?$),
    complete: [ 'toggle', %w[ markdown stream location runtime_info voice think_loud think_strip embedding ] ],
    help: <<~EOT
      🎛️ Toggle feature switches
      (markdown, stream, location, runtime_info,
      voice, think_loud, think_strip, embedding)
    EOT
  ) do |toggle_name|
    if toggle_name == 'embedding'
      embedding_paused.toggle(show: false)
      embedding.show
    elsif toggle_name
      send(toggle_name).toggle
    else
      STDOUT.puts "Available toggles: markdown|stream|location|runtime_info|voice|think_loud|think_strip|embedding"
    end
    :next
  end

  command(
    name: :favourite,
    regexp: %r(^/favourite(?:\s+(add|delete))?(?:\s+(model|prompt|system|persona|suggest))$),
    complete: [ 'favourite', %w[ add delete ], %w[ model prompt system persona suggest ] ],
    help: <<~EOT
      ⭐ Manage favorites (add/delete models,
         prompts, personae)
    EOT
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
    regexp: %r(^/model(?:\s+(change|options|options from session|options to session))(?:\s+(-p\s*\w+))?$),
    complete: [ 'model', %w[ change options options\ from\ session options\ to\ session ] ],
    help: <<~EOT
      🤖 Manage AI models & profiles:
         - change: Switch active model (-p [profile])
         - options: Edit saved profile config
         - options from session: Save live → Saved
         - options to session: Apply Saved → Live
    EOT
  ) do |subcommand, opts|
    case subcommand
    when 'change'
      opts = go_command('p:', opts, defaults: { ?p => 'default' })
      begin
        use_model(profile: opts[?p])
      rescue OllamaChat::UnknownModelError => e
        msg = "Caught #{e.class}: #{e}"
        log(:error, msg, data: { command: 'model', profile: opts[?p] }, warn: true)
      end
    when 'options'
      opts = go_command('p:', opts, defaults: { ?p => 'default' })
      edit_model_options(@model, profile: opts[?p])
    when 'options from session'
      opts = go_command('p:', opts, defaults: { ?p => 'default' })
      copy_model_options_from_session(profile: opts[?p])
    when 'options to session'
      opts = go_command('p:', opts, defaults: { ?p => 'default' })
      copy_model_options_to_session(profile: opts[?p])
    end
    :next
  end

  command(
    name: :system,
    regexp: %r(^/system(?:\s+(change))?$),
    complete: [ 'system', %w[ change ] ],
    optional: true,
    help: <<~EOT,
      🧬 Manage active system prompt (change)
         Note: Use '/prompt -c system' for managing
         (add, delete, edit, list, etc.) system templates.
    EOT
  ) do |subcommand, filename|
    case subcommand
    when 'change'
      change_system_prompt(@messages.system_name)
      @messages.show_system_prompt
    when nil
      @messages.show_system_prompt
    end
    :next
  end

  command(
    name: :think,
    regexp: %r(^/think$),
    help: <<~EOT
      🧠 Configure model thinking mode
    EOT
  ) do
    think_mode.choose
    :next
  end

  command(
    name: :context_format,
    regexp: %r(^/context_format$),
    help: <<~EOT,
      📐 Set context format (JSON|TOON)
    EOT
  ) do
    context_format.choose
    :next
  end

  command(
    name: :tools,
    regexp: %r(^/tools(?:\s+(on|off|enable|disable))?),
    complete: [ 'tools', %w[ on off enable disable ] ],
    optional: true,
    help: <<~EOT
      🛠 Manage tools:
         - (no subcommand): List available tools
         - on/off: Activate/Deactivate globally
         - enable/disable: Interactively toggle specific
    EOT
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
    help: <<~EOT
      🔊 Change voice output settings
    EOT
  ) do
    change_voice
    :next
  end

  ## Session

  command(
    name: :session,
    regexp: %r(^/session(?:\s+(change|previous|list|new|duplicate|rename|summarize|delete|model options change|model options))?((?:\s+-(?:[sf]|p\s*\w+))*)(?:\s+([^-].*))?$),
    complete: [ 'session', %w[ change previous list new duplicate rename summarize delete model\ options\ change model\ options ] ],
    optional: true,
    options: "[-s|-f|-p profile]\n[name]",
    help: <<~EOT
      💬 Manage sessions:
         - list/new/delete/rename/duplicate
         - change [name]/previous
         - summarize (-s sentence, -f save to file)
         - model options/change
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
      if opts[?f] and
          filename = ask?(prompt: "❓ Enter filename: ").full? { Pathname.new(_1) }
        then
        if filename.exist? && !confirm?(
            prompt: "🔔 File #{filename.to_s.inspect} already exists, overwrite? (y/n) ",
            yes: /\Ay/i
          )
        then
          STDERR.puts "File not written!"
          next :next
        end
        summary = summarize_session(pretty: true, sentence: opts[?s]) do |content|
          infobar.puts kramdown_ansi_parse(content)
        end
        if summary.full?
          filename.write(summary)
          STDOUT.puts "File successfully written."
          next :next
        else
          STDERR.puts "Nothing to summarize!"
          next :next
        end
      end
      summary = summarize_session(pretty: true, sentence: opts[?s]) do |content|
        infobar.puts kramdown_ansi_parse(content) << ?\n
      end
      if summary.full?
        use_pager do |output|
          output.puts kramdown_ansi_parse(summary)
        end
      else
        STDERR.puts "Nothing to summarize!"
        next :next
      end
    when 'change'
      change_session(name)
    when 'model options'
      edit_session_model_options
    when 'model options change'
      opts = go_command('p:', opts)
      if profile = opts[?p] || choose_profile_for_model(@model)
        copy_model_options_to_session(profile:)
      end
    when 'previous'
      if prev = previous_session
        change_session(prev.id)
      else
        STDOUT.puts "No previous session defined."
      end
    end
    :next
  end

  ## Conversation

  command(
    name: :list,
    regexp: %r(^/list((?:\s+(?:-[ts]))*)(?:\s+(\d*))?$),
    options: '[-t|-s|n=1]',
    help: <<~EOT
      📜 List conversation history
         Options: -t (show thinking), -s (hide)
    EOT
  ) do |opts,number|
    opts = go_command('ts', opts.to_s)
    n    = 2 * number.to_i if number
    think_loud = if opts[?t]
                   true
                 elsif opts[?s]
                   false
                 else
                   self.think_loud.on?
                 end
    messages.list_conversation(n, think_loud:)
    :next
  end

  command(
    name: :last,
    regexp:  %r(^/last((?:\s+(?:-[pts]))*)(?:\s+(\d*))?$),
    options: '[-p|-t|-s|n=1]',
    help: <<~EOT
      🔍 Show last message(s)
         Options: -p (plain), -t (show thinking),
                  -s (hide thinking)
    EOT
  ) do |opts,number|
    opts = go_command('pts', opts.to_s)
    n    = number.to_i.clamp(1..)
    think_loud = if opts[?t]
                   true
                 elsif opts[?s]
                   false
                 else
                   self.think_loud.on?
                 end
    messages.show_last(n, think_loud:, pager: !opts[?p])
    :next
  end

  command(
    name: :drop,
    regexp: %r(^/drop(?:\s+(\d*))?$),
    options: '[n=1]',
    help: <<~EOT
      🗑 Remove last exchanges (undo)
    EOT
  ) do
    messages.drop(_1)
    messages.show_last
    :next
  end

  command(
    name: :clear,
    regexp: %r(^/clear(?:\s+(messages|images|links|history|tags|all))?$),
    complete: [ 'clear', %w[ messages images links history tags all ] ],
    optional: true,
    help: <<~EOT
      🧹 Clear chat state (messages, images, links,
         history, tags, all)
    EOT
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
    help: <<~EOT,
      🔗 Display or clear tracked links
        (alias for /clear links)
    EOT
  ) do |subcommand|
    manage_links(subcommand)
    :next
  end

  command(
    name: :regenerate,
    regexp: %r(^/regenerate(\s+-e)?\s*$),
    help: <<~EOT
      🔄 Regenerate last AI response
         (-e to edit prompt before regenerating)
    EOT
  ) do |opts|
    opts = go_command('e', opts)
    if message = messages.find_last { !_1.tool? && _1.role == 'user' }
      content = message.content.to_s
      messages.drop(1)
      content = edit_text(content) if opts[?e]
    else
      STDOUT.puts "Not enough messages in this conversation."
      next :redo
    end
    disable_content_parsing
    content
  end

  command(
    name: :prompt,
    regexp: %r(^/prompt(?:\s+(edit|info|add|delete|list|duplicate|import|export|reset|-e))?(\s+(?:-[ef]|-c\s+\w+))?(?:\s+([^-].*))?$),
    complete: [ 'prompt', %w[ edit info add delete list duplicate import export reset ] ],
    optional: true,
    options: '[-c CONTEXT|-e|-f]',
    help: <<~EOT,
      📝 Manage prompt templates:
         Subcommands: edit, info, add, delete, list,
         duplicate, import, export, reset.
         Options: -c [context], -e (edit next)
    EOT
  ) do |subcommand, opts, filename|
    opts = go_command('fc:', opts)
    case subcommand
    when 'add'
      add_new_prompt(context: opts[?c])
    when 'delete'
      choose_and_delete_prompt(context: opts[?c], force: opts[?f])
    when 'edit'
      choose_and_edit_prompt(context: opts[?c])
    when 'list'
      list_prompts(context: opts[?c])
    when 'duplicate'
      duplicate_prompt(context: opts[?c])
    when 'import'
      import_prompt(filename, context: opts[?c])
    when 'export'
      export_prompt(context: opts[?c])
    when 'info'
      info_prompt(context: opts[?c])
    when 'reset'
      if prompt = choose_prompt(
          default: true,
          context: opts[?c],
          prompt: 'Which prompt needs to be restored to its origin? %s'
        )
      then
        if reset_prompt_to_default(prompt.name, context: opts[?c])
          STDOUT.puts "Reset prompt #{bold{prompt.name}} to default."
        else
          STDOUT.puts "No default value found for prompt #{bold{prompt.name}}."
        end
      end
    when nil, '-e'
      if prompt = choose_prompt(prompt: 'Which template shall guide the next response? %s').full?(&:to_s)
        if subcommand
          prompt = edit_text(prompt)
          next prompt
        else
          self.prefill_prompt = prompt
        end
      end
    end
    :next
  end

  command(
    name: :suggest,
    regexp: %r(^/suggest(\s+(?:-e))?$),
    options: '[-e]',
    help: <<~EOT,
      💡 Generate follow-up prompts from history
         Uses strategies ('coding', 'roleplaying', etc.)
         Options: -e (edit suggestion in editor)
    EOT
  ) do |opts|
    opts = go_command('e', opts)
    if prompt = suggest_prompts(edit: opts[?e])
      self.prefill_prompt = prompt
    end
    :next
  end

  command(
    name: :change_response,
    regexp: %r(^/change response$),
    complete: %w[ change response ],
    help: <<~EOT,
      ✏️ Edit last AI response in editor
    EOT
  ) do
    change_response
    :next
  end

  command(
    name: :conversation,
    regexp: %r(^/conversation\s+(save|load)((?:\s+-(?:[c]))*)\s+([^-].*)$),
    complete: [ 'conversation', %w[ save load ] ],
    options: '[-c]',
    help: <<~EOT
      💾 Save/Load conversation state
         (-c to clean first)
    EOT
  ) do |subcommand,opts,path|
    opts = go_command('c', opts.to_s)
    case subcommand
    when 'save'
      save_conversation(path, clean: opts[?c])
    when 'load'
      load_conversation(path)
      repair_group_uuids
    end
    :next
  end

  ## Collection

  command(
    name: :collection,
    regexp: %r(^/collection(?:\s+(change|clear|list|rename|update))?$),
    complete: [ 'collection', %w[ change clear list rename update ] ],
    optional: true,
    help: <<~EOT
      📚 Manage RAG collections:
         - change/clear/list/rename
         - update: Re-index modified docs
         - (no subcommand): Show stats
    EOT
  ) do |subcommand|
    case subcommand
    when 'clear'
      clear_collection
    when 'change'
      choose_collection(collection)
    when 'list'
      list_collections
    when 'rename'
      rename_collection(collection)
    when 'update'
      if results = update_collection
        disable_content_parsing
        next results
      end
    when nil
      collection_stats
    end
    :next
  end

  ## Persona

  command(
    name: :persona,
    regexp: %r(^/persona(?:\s+(play|load|edit|info|list|add|delete|backup|import|export|duplicate|copy))?$),
    complete: [ 'persona', %w[ play load edit info list add delete backup import export duplicate copy ] ],
    optional: true,
    help: <<~EOT,
      🎭 Manage/activate personae:
         Activation: play, load, copy
         Management: add, edit, delete, duplicate,
                    list, info
         Portability: backup, export, import
    EOT
  ) do |subcommand|
    disable_content_parsing
    case subcommand
    when 'add'
      add_persona
      :next
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
      duplicate_persona
      :next
    when 'import'
      filename = choose_filename('**/*.md')
      if filename and name = import_persona(filename)
        STDOUT.puts "Imported persona as #{name.inspect}."
      end
      :next
    when 'export'
      export_persona
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
    when 'play'
      set_default_persona
      :next
    when 'copy'
      select_persona_path(no_prefill: true)
      :next
    else
      select_persona_path
      :next
    end
  end

  command(
    name: :character,
    regexp: %r(^/character(?:\s+(info|load|import))(?:\s+([^-].+))?$),
    complete: [ 'character', %w[ info load import ] ],
    options: '[path]',
    help: <<~EOT
      👤 Import/load character from JSON/PNG
         Options: [path] to specify file directly
    EOT
  ) do |subcommand, path|
    path = if path
             Pathname.new(path)
           else
             choose_filename('**/*.{png,json}')
           end
    case
    when path.nil?
      STDOUT.puts 'Cancelled.'
      next :next
    when !path.exist?
      STDERR.puts "Path #{path.to_s.inspect} does not exist!"
      next :next
    end
    data = case path.extname
           when '.json'
             path.read
           when '.png'
             path.open do |io|
               OllamaChat::Utils::PNGMetadataExtractor.extract_character(io)
             end
           else
             STDERR.puts "Only json and png characters are supported!"
             next :next
           end
    json_to_yaml = -> d {
      yaml = YAML.dump(JSON(d)).sub(%r{\A---\n}, '')
      Kramdown::ANSI::Width.wrap(
        yaml,
        length: Tins::Terminal.columns * 0.9
      )
    }
    case subcommand
    when 'info'
      use_pager do |output|
        output.puts json_to_yaml.(data)
      end
      :next
    when 'load'
      disable_content_parsing
      data
    when 'import'
      persona_name = import_persona_from_json(data)
      STDOUT.puts "Imported character as persona %s." % persona_name.to_s.inspect
      :next
    end
  end

  ## Input

  command(
    name: :compose,
    regexp: %r(^/compose$),
    help: <<~EOT
      ✍️  Compose message in external editor
    EOT
  ) do
    edit_text.full? or :next
  end

  command(
    name: :web,
    regexp: %r(^/web\s+(?:(\d+)\s+)?(.+)),
    options: '[number=1] query',
    help: <<~EOT
      🌐 Search web for
      (a specified number of results)
    EOT
  ) do |count, query|
    disable_content_parsing
    web(count, query)
  end

  command(
    name: :input,
    regexp: %r(^/input(?:\s+(path|context|embedding|summary)(?:\s*(?=\z))?)?((?:\s+-(?:[apre]|c\s*\w+|w\s*\d+|t\s*[-\w\.]+(?:,[-\w\.]+)*))*)(?:\s+([^-].*))?$),
    optional: true,
    complete: [ 'input', %w[ path context embedding summary ] ],
    options: <<~EOT,
      [
        -w|-a|-p|-e|
        -c <collection>|
        -t <tags>
      ]
      [arg…]
    EOT
    help: <<~EOT
      📥 Import content (read, summarize, embed, context)
         Subcommands: path, context, embedding, summary
         Options: -p (pattern), -w [words], -a (all),
                  -c [collection], -t [tags], -e (edit)
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
        next provide_file_set_content(patterns, all:, skip_blank: true) { summarize(_1, words:) } || :next
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
      disable_content_parsing
      opts = go_command('pac:t:', opts)
      switch_collection(opts[?c]) do |other_collection|
        if collection == other_collection and !confirm?(
          prompt: "🔔 Are you sure to embed into current collection #{other_collection.to_s.inspect}? (y/n) ",
          yes: /\Ay/i
        )
        then
          STDOUT.puts 'Cancelled.'
          next :next
        end
        tags = opts[?t].full?(:split, ?,)
        if opts[?p]
          all = opts.fetch(?a, false)
          arg and patterns = arg.scan(/(\S+)/).flatten
          next provide_file_set_content(patterns, all:, skip_blank: true) { embed(_1, tags:) } || :next
        elsif arg
          next embed(arg, tags:) || :next
        else
          STDERR.puts "Need a source to embed for input!"
          next :next
        end
      end
    when 'path'
      opts = go_command('pae', opts)
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
        filename.file? or next :next
        content = filename.read
        content = edit_text(content) if opts[?e]
        content
      else
        STDERR.puts "Need a filename to read for input!"
        next :next
      end
    else
      opts = go_command('pae', opts)
      if opts[?p]
        all = opts.fetch(?a, false)
        arg and patterns = arg.scan(/(\S+)/).flatten
        next provide_file_set_content(patterns, all:, skip_blank: true) { import(_1) } || :next
      elsif arg
        source = arg
        content = import(source) or next :next
        content = edit_text(content) if opts[?e]
        content
      else
        STDERR.puts "Need a source to import for input!"
        next :next
      end
    end
  end

  ## Output

  command(
    name: :pipe,
    regexp: %r(^/pipe(\s+-e)?\s+([^-].*)$),
    options: 'path',
    help: <<~EOT
      🔌 Pipe last response to command stdin
         (-e to edit before piping)
    EOT
  ) do |opts, command|
    opts = go_command('e', opts)
    pipe(command, edit: opts[?e])
    :next
  end

  command(
    name: :vim,
    regexp: %r(^/vim(?:\s+(.+))?$),
    options: '[servername]',
    help: <<~EOT
      🪟 Insert last message into Vim buffer
         Options: [servername]
    EOT
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
    regexp: %r(^/output(\s+-e)?\s+([^-].*)$),
    options: '[-e] path',
    help: <<~EOT
      💾 Save last response to file
         (-e to edit before saving)
    EOT
  ) do |opts, path|
    opts = go_command('e', opts)
    output(path, edit: opts[?e])
    :next
  end

  ## Actions

  command(
    name: :reconnect,
    regexp: %r(^/reconnect$),
    help: <<~EOT
      🔌 Reconnect to Ollama server
    EOT
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
    help: <<~EOT,
      🚪 Quit application
    EOT
  ) do
    quit_app
  end

  ## Information

  command(
    name: :info,
    regexp: %r(^/info(?:\s+(session|model|runtime|rag))?$),
    complete: [ 'info', %w[ session model runtime rag ] ],
    optional: true,
    help: <<~EOT,
      ℹ️ Show info:
         - session: Current chat details
         - model: Active AI model info
         - runtime: System/environmental data
         - rag: RAG document system status
    EOT
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
    regexp: %r(^/help(?:\s+(\S+))?$),
    optional: true,
    complete: [ 'help', %w[ me ] ],
    help: <<~EOT
      ❓ View help menu
         (use 'me' for AI help or pattern to filter)
    EOT
  ) do |subcommand|
    case subcommand
    when 'me'
      disable_content_parsing
      prompt(:help).to_s % { commands: help_message }
    when /\S+/
      display_chat_help(Regexp.new(Regexp.quote($&)))
      :next
    end
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

end
