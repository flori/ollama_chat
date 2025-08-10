module OllamaChat::Dialog
  # The model_with_size method formats a model's size for display
  # by creating a formatted string that includes the model name and its size
  # in a human-readable format with appropriate units.
  #
  # @param model [ Object ] the model object that has name and size attributes
  #
  # @return [ Object ] a result object with an overridden to_s method
  #                     that combines the model name and formatted size
  private def model_with_size(model)
    result = model.name
    formatted_size = Term::ANSIColor.bold {
      Tins::Unit.format(model.size, unit: ?B, prefix: 1024, format: '%.1f %U')
    }
    result.singleton_class.class_eval do
      define_method(:to_s) { "%s %s" % [ model.name, formatted_size ] }
    end
    result
  end

  # The choose_model method selects a model from the available list based on
  # CLI input or user interaction.
  # It processes the provided CLI model parameter to determine if a regex
  # selector is used, filters the models accordingly, and prompts the user to
  # choose from the filtered list if needed.
  # The method ensures that a model is selected and displays a connection
  # message with the chosen model and base URL.
  def choose_model(cli_model, current_model)
    selector = if cli_model =~ /\A\?+(.*)\z/
                 cli_model = ''
                 Regexp.new($1)
               end
    models = ollama.tags.models.sort_by(&:name).map { |m| model_with_size(m) }
    selector and models = models.grep(selector)
    model = if cli_model == ''
              OllamaChat::Utils::Chooser.choose(models) || current_model
            else
              cli_model || current_model
            end
  ensure
    STDOUT.puts green { "Connecting to #{model}@#{ollama.base_url} now…" }
  end

  # The ask? method prompts the user with a question and returns their input.
  #
  # @param prompt [ String ] the message to display to the user
  #
  # @return [ String ] the user's response with trailing newline removed
  def ask?(prompt:)
    print prompt
    STDIN.gets.chomp
  end

  # The choose_collection method presents a menu to select or create a document
  # collection. It displays existing collections along with options to create a
  # new one or exit.
  # The method prompts the user for input and updates the document collection
  # accordingly.
  #
  # @param current_collection [ String, nil ] the name of the currently active collection
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

  # The document_policy method sets the policy for handling document imports.
  #
  # @param value [ String ] the document policy to be set
  attr_writer :document_policy

  # The choose_document_policy method presents a menu to select a document policy.
  # It allows the user to choose from importing, embedding, summarizing, or
  # ignoring documents.
  # The method displays available policies and sets the selected policy as the
  # current document policy.
  # If no valid policy is found, it defaults to the first option.
  # After selection, it outputs the chosen policy and displays the current
  # configuration information.
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

  # The change_system_prompt method allows the user to select or enter a new
  # system prompt for the chat session.
  # It provides an interactive chooser when multiple prompts match the given
  # selector, and sets the selected prompt as the current system prompt for the
  # messages.
  #
  # @param default [ String ] the default system prompt to fall back to
  # @param system [ String ] the system prompt identifier or pattern to
  # search for
  def change_system_prompt(default, system: nil)
    selector = if system =~ /\A\?(.+)\z/
                 Regexp.new($1)
               else
                 Regexp.new(system.to_s)
               end
    prompts = config.system_prompts.attribute_names.compact.grep(selector).sort
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

  # The choose_prompt method presents a menu of available prompts for selection.
  # It retrieves the list of prompt attributes from the configuration,
  # adds an '[EXIT]' option to the list, and displays it to the user.
  # After the user makes a choice, the method either exits the chooser
  # or applies the selected prompt configuration.
  def choose_prompt
    prompts = config.prompts.attribute_names.sort
    prompts.unshift('[EXIT]')
    case chosen = OllamaChat::Utils::Chooser.choose(prompts)
    when '[EXIT]', nil
      STDOUT.puts "Exiting chooser."
      return
    when *prompts
      config.prompts.send(chosen)
    end
  end

  # The change_voice method allows the user to select a voice from a list of
  # available options. It uses the chooser to present the options and sets the
  # selected voice as the current voice.
  #
  # @return [ String ] the full name of the chosen voice
  def change_voice
    chosen  = OllamaChat::Utils::Chooser.choose(config.voice.list)
    @current_voice = chosen.full? || config.voice.default
  end

  # The message_list method creates and returns a new MessageList instance
  # initialized with the current object as its argument.
  #
  # @return [ MessageList ] a new MessageList object
  def message_list
    MessageList.new(self)
  end
end
