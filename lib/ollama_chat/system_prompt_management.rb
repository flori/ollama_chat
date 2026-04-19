# Provides advanced system prompt management capabilities for the OllamaChat
# session.
#
# This module encapsulates the logic for initializing, changing, and loading
# system prompts, allowing for dynamic and interactive configuration within the
# chat lifecycle.
module OllamaChat::SystemPromptManagement
  # Sets the current system prompt for the chat session.
  #
  # @param system [String] the system prompt to set
  def set_current_system_prompt(system)
    messages.set_system_prompt(system)
    session.update(current_system_prompt: system)
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
    default = session.current_system_prompt.full? ||
      system_prompt(:default).full?(:to_s) ||
      @model_metadata.system
    if @opts[?s] =~ /\A\?/
      change_system_prompt(default, system: @opts[?s])
    else
      system = OllamaChat::Utils::FileArgument.get_file_argument(@opts[?s], default:)
      system.present? and set_current_system_prompt(system)
    end
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
  # @return [String, nil] the system prompt that was set, or nil if cancelled
  def change_system_prompt(default, system: nil)
    selector = case system
               when /\A\?(.*)\z/
                 Regexp.new($1)
               else
                 Regexp.new(system.to_s)
               end
    prompts = each_system_prompt.map(&:name).grep(selector).sort
    if prompts.size == 1
      system = system_prompt(prompts.first).to_s
    else
      prompts.unshift('[EXIT]')
      chosen = OllamaChat::Utils::Chooser.choose(prompts)
      system =
        case chosen
        when '[EXIT]'
          STDOUT.puts "Exiting chooser."
          return
        when nil
          default
        when *prompts
          system_prompt(chosen).to_s
        else
          default
        end
    end
    set_current_system_prompt(system)
  end

  # Loads a system prompt from a file selected via an interactive file chooser.
  #
  # @param patterns [ Array<String> ] file patterns to filter the selection (e.g., ['*.txt', '*.md'])
  def load_system_prompt_from_file(patterns = nil)
    patterns = Array(patterns.full? || '**/*.{txt,md}')
    filename = choose_filename(patterns)

    if filename&.exist?
      content = filename.read
      set_current_system_prompt(content)
      STDOUT.puts "Successfully loaded system prompt from: #{filename}"
    else
      STDOUT.puts "No valid file selected or file does not exist."
    end
  end

  # Presents an interactive menu to select a stored system prompt.
  #
  # @return [Object, nil] the selected system prompt object, or nil if cancelled
  def choose_system_prompt
    prompts = each_system_prompt.map(&:name).sort
    prompts.unshift('[EXIT]')
    case chosen = OllamaChat::Utils::Chooser.choose(prompts)
    when '[EXIT]', nil
      STDOUT.puts "Exiting chooser."
      return
    when *prompts
      system_prompt(chosen)
    end
  end

  # Interactively prompts the user for a name and content to create a new
  # system prompt. Optionally sets the new prompt as the current one.
  #
  # @return [Boolean, nil] true if the prompt was added and set as current,
  #   false if added but not set, or nil if the process was cancelled
  def add_new_system_prompt
    name = nil
    loop do
      name = ask?(prompt: "❓ Enter new system prompt name to add: ")
      if name.nil?
        STDOUT.puts "Canceled."
        return nil
      end
      if system_prompt(name)
        STDOUT.puts "System prompt named #{bold{name}} already exists."
      else
        break
      end
    end
    system_prompt = compose
    store_system_prompt(name, system_prompt).to_s
    yes = confirm?(
      prompt: "🔔 Set the newly added prompt as current system prompt? (y/n) ",
      yes: /\Ay/i
    )
    if yes
      set_current_system_prompt(system_prompt)
      true
    else
      false
    end
  end

  # Interactively selects an existing system prompt and allows the user to
  # edit its content.
  #
  # @return [self, nil] the current context on success, or nil if cancelled
  def choose_and_edit_system_prompt
    prompt = choose_system_prompt or return
    prompt.metadata['content'] = compose(prompt.metadata['content'].to_s)
    prompt.save
    self
  end

  # Interactively selects an existing system prompt and deletes it after
  # confirmation.
  #
  # @return [self, nil] the current context on success, or nil if cancelled
  def choose_and_delete_system_prompt
    prompt = choose_system_prompt or return
    confirm?(
      prompt: "🔔 Really delete the system prompt #{bold{prompt.name}}? (y/n) ",
      yes: /\Ay/i
    ) or return
    prompt.destroy
    self
  end
end
