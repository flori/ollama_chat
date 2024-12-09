module OllamaChat::Dialog
  def choose_model(cli_model, current_model)
    models = ollama.tags.models.map(&:name).sort
    model = if cli_model == ''
              OllamaChat::Utils::Chooser.choose(models) || current_model
            else
              cli_model || current_model
            end
  ensure
    STDOUT.puts green { "Connecting to #{model}@#{ollama.base_url} now…" }
  end

  def ask?(prompt:)
    print prompt
    STDIN.gets.chomp
  end

  def choose_collection(current_collection)
    collections = [ current_collection ] + @documents.collections
    collections = collections.compact.map(&:to_s).uniq.sort
    collections.unshift('[EXIT]').unshift('[NEW]')
    collection = OllamaChat::Utils::Chooser.choose(collections) || current_collection
    case collection
    when '[NEW]'
      @documents.collection = ask?(prompt: "Enter name of the new collection: ")
    when nil, '[EXIT]'
      STDOUT.puts "Exiting chooser."
    when /./
      @documents.collection = collection
    end
  ensure
    STDOUT.puts "Using collection #{bold{@documents.collection}}."
    info
  end

  attr_writer :document_policy

  def choose_document_policy
    policies = %w[ importing embedding summarizing ignoring ].sort
    current  = if policies.index(@document_policy)
                 @document_policy
               elsif policies.index(config.document_policy)
                 config.document_policy
               else
                 policies.first
               end
    policies.unshift('[EXIT]')
    policy = OllamaChat::Utils::Chooser.choose(policies)
    case policy
    when nil, '[EXIT]'
      STDOUT.puts "Exiting chooser."
      policy = current
    end
    self.document_policy = policy
  ensure
    STDOUT.puts "Using document policy #{bold{@document_policy}}."
    info
  end

  def change_system_prompt(default, system: nil)
    selector = Regexp.new(system.to_s[1..-1].to_s)
    prompts  = config.system_prompts.attribute_names.compact.grep(selector)
    if prompts.size == 1
      system = config.system_prompts.send(prompts.first)
    else
      prompts.unshift('[EXIT]').unshift('[NEW]')
      chosen = OllamaChat::Utils::Chooser.choose(prompts)
      system =
        case chosen
        when '[NEW]'
          ask?(prompt: "Enter new system prompt to use: ")
        when '[EXIT]'
          STDOUT.puts "Exiting chooser."
          return
        when nil
          default
        when *prompts
          config.system_prompts.send(chosen)
        else
          default
        end
    end
    @messages.set_system_prompt(system)
  end

  def change_voice
    chosen  = OllamaChat::Utils::Chooser.choose(config.voice.list)
    @current_voice = chosen.full? || config.voice.default
  end

  def message_list
    MessageList.new(self)
  end
end
