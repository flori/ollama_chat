# A module that provides interactive selection and configuration functionality
# for OllamaChat.
#
# The Dialog module encapsulates various helper methods for choosing models,
# system prompts, document policies, and voices, as well as displaying
# information and managing chat sessions. It leverages user interaction
# components like choosers and prompts to enable dynamic configuration during
# runtime.
#
# @example Selecting a model from available options
#   chat.choose_model('-m llama3.1', 'llama3.1')
#
# @example Changing the system prompt
#   chat.change_system_prompt('default_prompt', system: '?sherlock')
module OllamaChat::Dialog
  # The ask? method prompts the user with a question and returns their input.
  #
  # @param prompt [ String ] the message to display to the user
  #
  # @return [ String ] the user's response with trailing newline removed
  def ask?(prompt:)
    print prompt
    STDIN.gets.to_s.chomp
  end

  # The confirm? method displays a prompt and reads a single character input
  # from the user in raw mode, then returns that character. This is best used
  # for confirmation prompts.
  #
  # @param prompt [ String ] the prompt to display to the user.
  # @return [ String ] the character entered by the user.
  def confirm?(prompt:)
    print prompt
    system 'stty raw'
    c = STDIN.getc
    system 'stty cooked'
    puts
    c
  end

  private

  # The choose_file_set method aggregates all files matching the given patterns
  # by repeatedly invoking choose_filename and collecting their expanded paths
  # into a Set.
  #
  # @param patterns [ Array<String> ] optional glob patterns to match; defaults
  #   to '**/*'.
  #
  # @return [ Set<Pathname> ] a set of expanded Pathname objects for each
  #   selected file.
  #
  def choose_file_set(patterns)
    patterns ||= '**/*'
    patterns = Array(patterns)
    files = Set[]
    while filename = choose_filename(patterns, chosen: files)
      files << filename.expand_path
    end
    files
  end

  # The connect_message method displays a connection status message.
  #
  # @param model [String] the model name to connect to
  # @param base_url [String] the base URL of the connection
  def connect_message(model, base_url)
    msg = "Connecting to #{model}@#{base_url} now…"
    log(:info, msg)
    STDOUT.puts green { msg }
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
      @documents.collection = ask?(prompt: "❓ Enter name of the new collection: ")
    when nil, '[EXIT]'
      STDOUT.puts "Exiting chooser."
    when /./
      @documents.collection = collection
    end
  ensure
    STDOUT.puts "Using collection #{bold{@documents.collection}}."
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
  #   search for
  def change_system_prompt(default, system: nil)
    selector = case system
               when /\A\?(.+)\z/
                 Regexp.new($1)
               when ??
                 /./
               else
                 Regexp.new(system.to_s)
               end
    prompts = config.system_prompts.attribute_names.compact.grep(selector).sort
    if prompts.size == 1
      system = config.system_prompts.send(prompts.first)
    else
      prompts.unshift('[NEW]').unshift('[EXIT]')
      chosen = OllamaChat::Utils::Chooser.choose(prompts)
      system =
        case chosen
        when '[NEW]'
          ask?(prompt: "❓ Enter new system prompt to use: ")
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
    @voices.choose
  end

  # The message_list method creates and returns a new MessageList instance
  # initialized with the current object as its argument.
  #
  # @return [ MessageList ] a new MessageList object
  def message_list
    MessageList.new(self)
  end

  def go_command(s, opt)
    Tins::GO.go(s, opt.to_s.strip.split(/\s+/))
  end
end
