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

  category :Clipboard

  command(
    name: :copy,
    regexp: %r(^/copy(\s+-e)?\s*$),
    options: '[-e]',
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
    regexp: %r(^/paste(\s+-[ie])*\s*$),
    options: '[-e|-i]',
    help: <<~EOT
      📋 Paste content from the clipboard or stdin.
         Options:
           -e  Edit after pasting.
           -i  Read from stdin instead of clipboard.
    EOT
  ) do |opts|
    disable_content_parsing
    opts = go_command('ie', opts)
    if opts[?i]
      paste_from_stdin(edit: opts[?e])
    else
      paste_from_clipboard(edit: opts[?e])
    end
  end

  category :Settings

  command(
    name: :config,
    regexp: %r(^/config(?:\s+(edit|diff|reload|env))?$),
    complete: [ 'config', %w[ edit diff reload env ] ],
    optional: true,
    help: <<~EOT
      \u2699 Manage configuration:
         - (no subcommand): View current config
         - edit: Open config in $EDITOR
         - diff: Diff against shipped defaults
         - reload: Restart and apply changes
         - env: Display Ollama Chat env var tree
    EOT
  ) do |subcommand|
    case subcommand
    when 'edit'
      edit_config
    when 'diff'
      diff_config
      reload_config
    when 'reload'
      reload_config
    when 'env'
      OC.view(pager: OC::PAGER?)
    else
      display_config
    end

    :next
  end

  command(
    name: :favourite,
    regexp: %r(^/favourite(?:\s+(add|delete))?(?:\s+(model|prompt|system|persona|suggest))$),
    complete: [ 'favourite', %w[ add delete ].product(%w[ model prompt system persona suggest ]) ],
    help: <<~EOT
      \u2B50 Manage favorites (add/delete models,
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

  category :Session

  command(
    name: :session,
    regexp: %r(^/session(?:\s+(change|previous|list|new|duplicate|rename|delete|model options change|model options|trigger edit))?((?:\s+-(?:p\s*\w+))*)(?:\s+([^-].*))?$),
    complete: [ 'session', %w[ change previous list new duplicate rename delete model\ options\ change model\ options trigger\ edit ] ],
    optional: true,
    options: "[-p profile]\n[name]",
    help: <<~EOT
      💬 Manage sessions:
         - list/new/delete/rename/duplicate
         - change [name]/previous
          - model options/change
          - trigger edit
    EOT
  ) do |subcommand, opts, name|
    case subcommand
    when nil
      info_session
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
        feedback("No previous session defined.", type: :info)
      end
    when 'trigger edit'
      edit_session_trigger
    end
    :next
  end

  command(
    name: :toggle,
    regexp: %r(^/toggle(?:\s+(markdown|stream|location|runtime_info|voice|think_loud|think_strip|embedding|memory_trigger)(?:\s+(-[yn]))?)?$),
    complete: [ 'toggle', %w[ markdown stream location runtime_info voice think_loud think_strip embedding memory_trigger ] ],
    options: '[-y|-n]',
    help: <<~EOT
      🎛️ Toggle feature switches
       (markdown, stream, location, runtime_info,
       voice, think_loud, think_strip, embedding, memory_trigger)
      Options: -y (on), -n (off)
    EOT
  ) do |toggle_name, flag|
    if toggle_name == 'embedding'
      if flag == '-y'
        embedding_paused.set(false)
      elsif flag == '-n'
        embedding_paused.set(true)
      else
        embedding_paused.toggle(show: false)
      end
      embedding.show
    elsif toggle_name
      switch = send(toggle_name)
      if flag == '-y'
        switch.set(true, show: true)
      elsif flag == '-n'
        switch.set(false, show: true)
      else
        switch.toggle
      end
    else
      feedback(
        "Available toggles: markdown|stream|location|runtime_info|voice|think_loud|think_strip|embedding|memory_trigger"
      )
    end
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
    name: :context_format,
    regexp: %r(^/context_format$),
    help: <<~EOT,
      📐 Set context format (JSON|TOON)
    EOT
  ) do
    context_format.choose
    :next
  end


  category :Conversation

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
    regexp:  %r(^/last((?:\s+(?:-[ptsv]))*)(?:\s+(\d*))?$),
    options: '[-p|-t|-s|n=1]',
    help: <<~EOT
      🔍 Show or speak last message(s)
         Options: -p (plain), -t (show thinking),
                  -s (hide thinking) -v (voice output)
    EOT
  ) do |opts,number|
    opts = go_command('ptsv', opts.to_s)
    n    = number.to_i.clamp(1..)
    if opts[?v]
      messages.speak_last(n)
    else
      think_loud =
        if opts[?t]
          true
        elsif opts[?s]
          false
        else
          self.think_loud.on?
        end
      messages.show_last(n, think_loud:, pager: !opts[?p])
    end
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
      feedback("Not enough messages in this conversation.", type: :warn)
      next :redo
    end
    disable_content_parsing
    content
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
    regexp: %r(^/conversation\s+(clean|compact summary|compact|save|load|summarize|report)((?:\s+-[sc])*)(?:\s+([^-].*\.jsonl?))?$),
    complete: [ 'conversation', %w[ compact clean report compact\ summary summarize save load ] ],
    options: '[-s|-c] [FILENAME]',
    help: <<~EOT
      💾 Manage conversation content:
         - save/load: Export/import as .json or .jsonl
         - clean: Remove tool content, images, thinking
         - compact: Summarize old messages, keep recent
         - compact summary: Show last compaction summary
         - summarize: Per-message narrative (-s sentence)
         - report: Generate a session report document
    EOT
  ) do |subcommand,opts,path|
    if %w[ save load ].include?(subcommand) && path.blank?
      feedback("Require a path as argument to save/load!", type: :warn)
      next :next
    end
    case subcommand
    when 'save'
      opts = go_command('c', opts.to_s)
      save_conversation(path, clean: opts[?c])
    when 'load'
      load_conversation(path)
      repair_group_uuids
    when 'clean'
      if confirm?(
          prompt: '🔔 Clean tool content, images, and thinking from conversation? (y/n) ',
          yes: /\Ay/i
        )
      then
        messages.clean_messages!
        session_sync
        feedback("Conversation cleaned.", type: :info)
      else
        feedback("Denied.", type: :denied)
      end
    when 'compact summary'
      show_compaction_summary
    when 'compact'
      compact_with_retry
    when 'summarize'
      opts = go_command('s', opts)
      summarize_conversation(sentence: opts[?s])
    when 'report'
      report_conversation
    end
    :next
  end

  category :Prompts

  command(
    name: :prompt,
    regexp: %r(^/prompt(?:\s+(edit|info|add|delete|list|duplicate|import|export|reset count|reset|rename|sync|-e))?(\s+(?:-[ef]|-c\s+(?:\w+|\?)))?(?:\s+([^-].*))?$),
    complete: [ 'prompt', %w[ edit info add delete list duplicate import export reset\ count reset rename sync ] ],
    optional: true,
    options: '[-c CONTEXT|-e|-f]',
    help: <<~EOT,
      📝 Manage prompt templates:
          Subcommands: edit, info, add, delete, list,
          duplicate, import, export, reset count, reset,
          rename, sync.
         Options: -c [context]
                     (? for interactive in /prompt),
                  -e (edit next)
    EOT
  ) do |subcommand, opts, filename|
    opts = go_command('fc:', opts)
    context = case subcommand
              when nil, '-e'
                if opts[?c] == ??
                  choose_prompt_context
                else
                  opts[?c] || 'prompt'
                end
              when 'reset count'
                'prompt'
              else
                opts[?c] || choose_prompt_context
              end
    unless context
        feedback("Cancelled.", type: :cancel)
       next :next
    end

    case subcommand
    when 'add'
      add_new_prompt(context:)
    when 'delete'
      choose_and_delete_prompt(context:, force: opts[?f])
    when 'edit'
      choose_and_edit_prompt(context:)
    when 'list'
      list_prompts(context:)
    when 'duplicate'
      duplicate_prompt(context:)
    when 'rename'
      rename_prompt(context:)
    when 'import'
      import_prompt(filename, context:)
    when 'export'
      export_prompt(context:)
    when 'info'
      info_prompt(context:)
    when 'reset count'
      choose_and_reset_count(context:)
    when 'reset'
      if prompt = choose_prompt(
          default: true,
          context:,
          prompt: 'Which prompt needs to be restored to its origin? %s'
        )
      then
        if reset_prompt_to_default(prompt.name, context:)
          feedback("Reset prompt #{bold{prompt.name}} to default.", type: :info)
        else
          feedback(
            "No default value found for prompt #{bold{prompt.name}}.",
            type: :warn
          )
        end
      end
    when 'sync'
      prompt_sync(context:)
    when nil, '-e'
      if prompt = choose_prompt(
          prompt:  'Which template shall guide the next response? %s',
          context: ,
          count:   true
        ).full?(&:to_s)
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

  category :Models

  command(
    name: :model,
    regexp: %r(^/model(?:\s+(change|options(?: copy| delete| export| import)?|options from session|options to session))?((?:\s+(?:-m|-p\s+[\S]+))*)$),
    complete: [ 'model', %w[ change options options\ copy options\ delete options\ export options\ import options\ from\ session options\ to\ session ] ],
    options: '[-m|-p pattern]',
    help: <<~EOT
      🤖 Manage AI models & profiles:
         - change: Switch active model
         - options: Edit saved profile config
         - options copy: Copy profile from another model
         - options delete: Delete a saved profile
         - options export: Export ALL model profiles to JSON
         - options import: Selectively import profiles from JSON
         - options from session: Save live → Saved
         - options to session: Apply Saved → Live
         -m interactively choose a model
         -p PATTERN narrow file search for import
    EOT
  ) do |subcommand, opts|
    if subcommand == 'change'
      begin
        model   = choose_model('', @model)
        profile = choose_profile_for_model(model) || 'default'
        use_model(model, profile:)
      rescue OllamaChat::UnknownModelError => e
        msg = "Caught #{e.class}: #{e}"
        log(:error, msg, data: { command: 'model', profile: }, warn: true)
      end
      next :next
    end
    opts    = go_command('mp:', opts)
    model   = opts[?m] ? choose_model('', @model) : @model
    case subcommand
    when 'options'
      profile = choose_profile_for_model(model, allow_new: true) or next :next
      edit_model_options(model, profile:)
    when 'options copy'
      copy_model_options_profile(model)
    when 'options delete'
      delete_model_options_profile(model)
    when 'options from session'
      profile = choose_profile_for_model(model) || 'default'
      copy_model_options_from_session(model, profile:)
    when 'options to session'
      profile = choose_profile_for_model(model) || 'default'
      copy_model_options_to_session(model, profile:)
    when 'options export'
      export_model_options
    when 'options import'
      pattern  = opts[?p] || '**/*.json'
      filename = choose_filename(pattern) or next :next
      import_model_options(filename)
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

  category :Collection

  command(
    name: :collection,
    regexp: %r(^/collection(?:\s+(change|clear(?: (?:tags|sources))?|list|rename|update(?: all)?|new|edit|delete|query))?((?:\s+-[er])*)?$),
    complete: [ 'collection', %w[ change clear\ tags clear\ sources clear list rename update update\ all new edit delete query ] ],
    optional: true,
    help: <<~EOT
      📚 Manage RAG collections:
          - change/clear/clear tags/clear sources/list/rename
         - update: Re-index modified docs
         - update all: Re-index all collections
         - new: Interactively create a new collection
         - edit: Interactively update an existing collection
         - delete: Permanently remove a collection
         - query: Search collection (-e edit, -r rerank)
         - (no subcommand): Show stats
    EOT
  ) do |subcommand, opts|
    case subcommand
    when 'clear'
      clear_whole_collection
    when 'clear tags'
      clear_collection_tags
    when 'clear sources'
      clear_collection_sources
    when 'change'
      choose_collection(collection)
    when 'list'
      list_collections
    when 'rename'
      rename_collection(collection)
    when 'update all'
      results = ''
      all_collections.pluck(:name).each do |collection|
        feedback("📝 Updating collection #{collection.inspect}…")
        results << update_collection(collection) << ?\n
        feedback("Done.", type: :success)
      end
      results.full? and next results
    when 'update'
      if results = update_collection(collection)
        disable_content_parsing
        next results
      end
    when 'new'
      create_collection
    when 'edit'
      edit_collection
    when 'delete'
      delete_collection
    when 'query'
      opts = go_command('er', opts.to_s)
      query_collection(edit: opts[?e], rerank: opts[?r])
    when nil
      collection_stats
    end
    :next
  end

  category :Persona

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
        feedback("Imported persona as #{name.inspect}.", type: :info)
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
      feedback("Cancelled.", type: :cancel)
      next :next
    when !path.exist?
      feedback("Path #{path.to_s.inspect} does not exist!", type: :warn)
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
              feedback("Only json and png characters are supported!", type: :warn)
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
      feedback(
        "Imported character as persona %s." % persona_name.to_s.inspect,
        type: :info
      )
      :next
    end
  end

  category :Input

  command(
    name: :compose,
    regexp: %r(^/compose(\s+-r)?\s*$),
    options: '[-r]',
    help: <<~EOT
      \u270D  Compose message in external editor
         Options: -r pre-fill with quoted last assistant reply
    EOT
  ) do |opts|
    opts = go_command('r', opts)
    prefill = if opts[?r]
      if msg = messages.find_last(content: true) { !_1.tool? && _1.role == 'assistant' }
        msg.content.to_s.lines.map { "> #{_1}" }.join + "\n\n"
      else
        feedback('No assistant message to quote.', type: :warn)
        next :next
      end
    end
    edit_text(prefill).full? or :next
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
    regexp: %r(^/input(?:\s+(path|context|embedding|summary)(?:\s*(?=\z))?)?((?:\s+-(?:[apreim]|c\s*#{OllamaChat::COLLECTION_NAME_REGEXP.source}|w\s*\d+|t\s*[-\w\.]+(?:,[-\w\.]+)*|l\s*[-\w]+))*)(?:\s+([^-].*))?$),
    optional: true,
    complete: [ 'input', %w[ path context embedding summary ] ],
    options: <<~EOT,
       [
          -w|-a|-p|-e|-m|-i|
         -c <collection>|
         -t <tags>|
         -l <language>
       ]
      [arg…]
    EOT
    help: <<~EOT
      📥 Import content (read, summarize, embed, context)
         Subcommands: path, context, embedding, summary
           Options: -p (pattern), -w [words], -a (all),
                    -c [collection], -t [tags], -e (edit),
                    -m (monochrome), -i (summary instruction),
                    -l [language]
    EOT
  ) do |input_mode,opts,arg|
    disable_content_parsing
    case input_mode
    when 'summary'
      opts = go_command('paw:i', opts)
      instruction =
        if opts[?i]
          switch_history(:instruction) {
            ask?(prompt: 'Summary instruction (Enter to skip): ').full?(:strip)
          }
        end
      if opts[?p]
        words = opts.fetch(?w, 100)
        all   = opts.fetch(?a, false)
        patterns = extract_patterns(arg)
        next provide_file_set_content(patterns, all:, skip_blank: true) { summarize(_1, words:, instruction:) } || :next
      elsif arg
        words = opts.fetch(?w, 100)
        source = arg
        next summarize(source, words:, instruction:) || :next
      else
        feedback("Need a source to summarize for input!", type: :warn)
        next :next
      end
    when 'context'
      opts = go_command('pa', opts)
      if opts[?p]
        all      = opts.fetch(?a, false)
        patterns = extract_patterns(arg).full? || [ '**/*' ]
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
          feedback("Denied.", type: :denied)
          next :next
        end
        tags = opts[?t].full?(:split, ?,)
        if opts[?p]
          all = opts.fetch(?a, false)
          patterns = extract_patterns(arg)
          sources = file_set_each(patterns, all:).map(&:to_s).to_h { [_1, tags] }
          next bulk_embed_sources(sources) || :next
        elsif arg
          next embed(arg, tags:) || :next
        else
          feedback("Need a source to embed for input!", type: :warn)
          next :next
        end
      end
    when 'path'
      opts = go_command('paem', opts)
      if opts[?p]
        all = opts.fetch(?a, false)
        patterns = extract_patterns(arg)
        read = -> pathname {
          feedback "Reading #{pathname.to_s.inspect}."
          content = pathname.read
          opts[?m] ? OllamaChat::Utils::StripANSI.strip_ansi(content) : content
        }
        next provide_file_set_content(patterns, all:, &read) || :next
      elsif arg
        filename = Pathname.new(arg).expand_path
        filename.file? or next :next
        content = filename.read
        content = OllamaChat::Utils::StripANSI.strip_ansi(content) if opts[?m]
        content = edit_text(content) if opts[?e]
        content
      else
        feedback("Need a filename to read for input!", type: :warn)
        next :next
      end
    else
      opts = go_command('paeml:', opts)
      if opts[?p]
        all = opts.fetch(?a, false)
        patterns = extract_patterns(arg)
        next provide_file_set_content(patterns, all:, skip_blank: true) do |src|
          content = import(src, language: opts[?l])
          opts[?m] ? OllamaChat::Utils::StripANSI.strip_ansi(content) : content
        end || :next
      elsif arg
        source = arg
        content = import(source, language: opts[?l]) or next :next
        content = OllamaChat::Utils::StripANSI.strip_ansi(content) if opts[?m]
        content = edit_text(content) if opts[?e]
        content
      else
        feedback("Need a source to import for input!", type: :warn)
        next :next
      end
    end
  end

  category :Output

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
      feedback("No message found to insert into Vim.", type: :warn)
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

  category :Actions

  command(
    name: :reconnect,
    regexp: %r(^/reconnect$),
    help: <<~EOT
      🔌 Reconnect to Ollama server
    EOT
  ) do
    feedback green { "Reconnecting to ollama #{base_url.to_s.inspect}…" }, type: :info
    connect_ollama
    feedback green { "Done." }, type: :success
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

  category :Information

  command(
    name: :info,
    regexp: %r(^/info(?:\s+(session|model|runtime|rag))?$),
    complete: [ 'info', %w[ session model runtime rag ] ],
    optional: true,
    help: <<~EOT,
      \u2139 Show info:
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
      prompt(:help).to_s.named_placeholders_interpolate({ commands: help_message })
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
    feedback "Type /quit to quit."
    :next
  end
end
