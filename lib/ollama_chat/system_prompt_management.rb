# Provides advanced system prompt management capabilities for the OllamaChat
# session.
#
# This module encapsulates the logic for initializing, changing, and loading
# system prompts, allowing for dynamic and interactive configuration within the
# chat lifecycle.
module OllamaChat::SystemPromptManagement
  # Retrieves all stored system prompts, decorated with a heart if they are
  # marked as favourites.
  #
  # @return [Array<SearchUI::Wrapper>] the list of system prompts for display
  #   in a chooser
  def all_system_prompts
    favs = all_favourited('system_prompt')
    each_system_prompt.sort_by(&:name).map do |p|
      system_prompt_with_favourite(p.name, favs[p.name])
    end
  end

  # Retrieves the default system prompt associated with the current model.
  #
  # @return [String, nil] the default system prompt from the model metadata,
  #   or nil if the metadata is not available.
  def model_default_system_prompt
    @model_metadata&.system
  end

  # Sets the current system prompt for the chat session.
  #
  # @param system_prompt_name [String] the system prompt to set
  def set_current_system_prompt(system_prompt_name)
    messages.set_system_prompt(system_prompt_name)
    session.update(current_system_prompt: system_prompt_name)
  end

  # Returns the name of the system prompt currently active in the chat session.
  #
  # @return [String, nil] the name of the current system prompt,
  #   or nil if no system prompt is set.
  def current_system_prompt_name
    messages.system_name
  end

  # Retrieves the content of the system prompt currently active in the chat
  # session.
  #
  # @return [String, nil] the content of the current system prompt, or nil if
  #   no system prompt is set.
  def current_system_prompt
    messages.system
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
    system_prompt_name = session.current_system_prompt.full? ||
      ('default' if system_prompt(:default)) ||
      'model_default'
    if system_prompt_name.full?
      set_current_system_prompt(system_prompt_name)
    else
      change_system_prompt(system_prompt_name)
    end
  end

  # The change_system_prompt method allows the user to select or enter a new
  # system prompt for the chat session.
  # It provides an interactive chooser when multiple prompts match the given
  # selector, and sets the selected prompt as the current system prompt for
  # the messages.
  #
  # The user can choose from all stored system prompts, the model's default,
  # or exit the chooser. If the selection is cancelled or returns nil,
  # the provided default is used.
  #
  # @param default [String] the system prompt name to use as a fallback
  # @return [Object, nil] the result of setting the current system prompt, or
  #   nil if the operation was explicitly exited.
  def change_system_prompt(default)
    prompts = all_system_prompts
    prompts.unshift('[MODEL DEFAULT]').unshift('[EXIT]')
    chosen = OllamaChat::Utils::Chooser.choose(prompts)
    system_prompt_name =
      case chosen
      when '[EXIT]'
        STDOUT.puts "Exiting chooser."
        return
      when '[MODEL DEFAULT]'
        'model_default'
      when nil
        default
      when SearchUI::Wrapper
        chosen.value.to_s
      else
        default
      end
    set_current_system_prompt(system_prompt_name)
  end

  # Presents an interactive menu to select a stored system prompt.
  #
  # @return [Object, nil] the selected system prompt object, or nil if cancelled
  def choose_system_prompt
    prompts = all_system_prompts
    prompts.unshift('[EXIT]')
    case chosen = OllamaChat::Utils::Chooser.choose(prompts)
    when '[EXIT]', nil
      STDOUT.puts "Exiting chooser."
      return
    when SearchUI::Wrapper
      system_prompt(chosen.value)
    end
  end

  # Interactively prompts the user for a name and content to create a new
  # system prompt. Optionally sets the new prompt as the current one.
  #
  # @return [Boolean, nil] true if the prompt was added and set as current,
  #   false if added but not set, or nil if the process was cancelled
  def add_new_system_prompt
    system_prompt_name = determine_valid_new_name_for_system_prompt('to add') or return
    patterns = ask?(
      prompt: "❓ Enter file patterns to load file, C-c ⇒ cancel: ",
      prefill: '**/*.{txt,md}'
    )
    patterns.nil? and return
    content = nil
    patterns.present? and content = load_prompt_from_file(patterns)
    system_prompt = edit_text(content)
    store_system_prompt(system_prompt_name, system_prompt).to_s
    ask_to_set_current_system_prompt(system_prompt_name)
  end

  # Interactively selects an existing system prompt and allows the user to
  # edit its content.
  #
  # @return [self, nil] the current context on success, or nil if cancelled
  def choose_and_edit_system_prompt
    system_prompt = choose_system_prompt or return
    system_prompt.metadata['content'] = edit_text(system_prompt.metadata['content'].to_s)
    system_prompt.save
    ask_to_set_current_system_prompt(system_prompt.name)
    self
  end

  # Interactively selects an existing system prompt and deletes it after
  # confirmation.
  #
  # @return [self, nil] the current context on success, or nil if cancelled
  def choose_and_delete_system_prompt
    system_prompt = choose_system_prompt or return
    STDOUT.puts kramdown_ansi_parse(
      system_prompt.to_s + "\n---"
    )
    confirm?(
      prompt: "🔔 Really delete the system prompt #{bold{system_prompt.name}}? (y/n) ",
      yes: /\Ay/i
    ) or return
    system_prompt.destroy
    self
  end

  # Lists all stored system prompts in a formatted view, displaying their
  # default status and a truncated preview of their content.
  #
  # @return [Array] an array of the results of the printing operations
  def list_system_prompts
    favs = all_favourited('system_prompt')
    each_system_prompt.sort_by(&:name).map do |prompt|
      default = prompt.metadata['default'] ? '⛭' : '✎'
      start   = '%s %s' % [ default, bold { prompt.name } ]
      start   = prefix_favourite(start, favs[prompt.name])
      content = prompt.to_s.inspect[1..-2]
      content = Kramdown::ANSI::Width.truncate(
        content, length: 0.9 * (Tins::Terminal.columns - start.size)
      )
      STDOUT.print start
      STDOUT.puts ' %s' % italic { content }
    end
  end

  # Duplicates an existing system prompt.
  #
  # This method initiates an interactive workflow:
  # 1. Prompts the user to select a system prompt to clone.
  # 2. Displays the content of the selected prompt for verification.
  # 3. Requests a new name for the duplicate, validating that it does
  #    not already exist in the database.
  # 4. Creates and saves the new prompt record using the {Duplicatable} mixin.
  #
  # @return [self, nil] the current context on success, or nil if the user
  #   cancelled the operation or no system prompt was selected.
  def duplicate_system_prompt
    system_prompt = choose_system_prompt or return
    STDOUT.puts kramdown_ansi_parse(
      system_prompt.to_s + "\n---"
    )
    system_prompt_name = determine_valid_new_name_for_system_prompt('to ducplicate as') or return
    duplicated_prompt = system_prompt.duplicate
    duplicated_prompt.name = system_prompt_name
    duplicated_prompt.metadata['default'] = false
    duplicated_prompt.save
    self
  end

  # Imports a system prompt from a file.
  #
  # This method prompts the user for a name for the imported prompt, reads the
  # content from the specified file, stores it, and then asks whether to set it
  # as the current system prompt.
  #
  # @param filename [String, Pathname] the path to the file containing the
  #   system prompt
  # @return [self, nil] self or nil if cancelled
  def import_system_prompt(filename)
    if filename
      if File.exist?(filename)
        filename = Pathname.new(filename)
      else
        filename = choose_filename(filename)
      end
    else
      filename = choose_filename('**/*.md')
    end
    unless filename
      STDOUT.puts "Canceled."
      return
    end
    system_prompt_name = determine_valid_new_name_for_system_prompt('to import') or return
    system_prompt = filename.read
    store_system_prompt(system_prompt_name, system_prompt)
    ask_to_set_current_system_prompt(system_prompt_name)
    STDOUT.puts "Imported system prompt as #{system_prompt_name.inspect}."
    self
  end

  # Interactively exports a system prompt to a specified file.
  #
  # The process follows these steps:
  # 1. Prompts the user to select a system prompt via `choose_system_prompt`.
  # 2. Displays the system prompt's current content to the terminal.
  # 3. Prompts for a destination filename via
  #   `determine_valid_output_filename`.
  # 4. Writes the system prompt content to the chosen file.
  #
  # @return [self, nil] returns self if the export was successful, or nil if
  #   the process was cancelled during system prompt selection or filename entry.
  def export_system_prompt
    prompt = choose_system_prompt or return
    STDOUT.puts kramdown_ansi_parse(
      prompt.to_s + "\n---"
    )
    filename = determine_valid_output_filename('to write to') or return
    filename.write(prompt.to_s)
    STDOUT.puts "Prompt #{prompt.name.inspect} was exported as #{filename.to_path.inspect}?"
    self
  end

  private

  # Helper to wrap a system prompt name with its favourite status for the UI.
  #
  # @param name [String] the name of the system prompt
  # @param favourited [Boolean] whether the system prompt is marked as a
  #   favourite
  # @return [SearchUI::Wrapper] a wrapper containing the original name and the
  #   decorated display string
  def system_prompt_with_favourite(name, favourited)
    display = prefix_favourite(name, favourited)
    SearchUI::Wrapper.new(name, display:)
  end

  # Interactively prompts the user for a new system prompt name and ensures it
  # is unique within the system.
  #
  # @param action [String] a description of the action being performed (e.g.,
  #   "to add") to be used in the prompt message.
  # @return [String, nil] the unique system prompt name entered by the user,
  #   or nil if the operation was cancelled.
  def determine_valid_new_name_for_system_prompt(action)
    system_prompt_name = nil
    loop do
      system_prompt_name = ask?(prompt: "❓ Enter new system prompt name #{action}, C-c ⇒ cancel: ")
      if system_prompt_name.nil?
        STDOUT.puts "Canceled."
        return nil
      end
      if system_prompt(system_prompt_name)
        STDOUT.puts "System prompt named #{bold{system_prompt_name}} already exists."
      else
        break
      end
    end
    system_prompt_name
  end

  # Asks the user for confirmation to set a specific system prompt as the
  # current one.
  #
  # @param system_prompt_name [String] the name of the system prompt to
  #   potentially set.
  # @return [Boolean] true if the prompt was set as current, false otherwise.
  def ask_to_set_current_system_prompt(system_prompt_name)
    yes = confirm?(
      prompt: "🔔 Set the new prompt as current system prompt? (y/n) ",
      yes: /\Ay/i
    )
    if yes
      set_current_system_prompt(system_prompt_name)
      true
    else
      false
    end
  end
end
