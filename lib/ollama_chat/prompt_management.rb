# Provides administrative and interactive management for
# prompt templates stored in the database.
#
# This module handles the user-facing selection process for
# prompts, allowing users to interactively pick a prompt from
# the database.
module OllamaChat::PromptManagement
  # Retrieves all stored prompts, decorated with a heart if they are marked as
  # favourites.
  #
  # @param default [Boolean, nil] filter for default prompts (true: only
  #   defaults, false: only non-defaults)
  #
  # @return [Array<SearchUI::Wrapper>] the list of prompts for display in a
  #   chooser
  def all_prompts(default: nil, context: nil)
    context ||= 'prompt'
    favs = all_favourited(context)
    each_prompt(context:, default:).sort_by(&:name).map do |p|
      prompt_with_favourite(p.name, favs[p.name])
    end
  end

  # The choose_prompt method presents a menu of available prompts for
  # selection. It retrieves the list of prompt names from the database, adds an
  # '[EXIT]' option, and displays them via the Chooser utility.
  #
  # @param default [Boolean, nil] filter for default prompts (true: only
  #   defaults, false: only non-defaults)
  # @param prompt [String] the prompt message to display when asking for input
  #
  # @return [OllamaChat::Database::Models::Prompt, nil] the selected prompt
  #   model, or nil if the user chooses '[EXIT]' or cancels the selection.
  def choose_prompt(default: nil, context: nil, prompt: "Select a #{context || 'prompt'} template: %s")
    context ||= 'prompt'
    prompts = all_prompts(default:, context:)
    prompts.unshift('[EXIT]')
    case chosen = choose_entry(prompts, prompt:)
    when '[EXIT]', nil
      STDOUT.puts "Exiting chooser."
      return
    when SearchUI::Wrapper
      prompt(chosen.value, context:)
    end
  end

  # Displays detailed information about a selected prompt template.
  #
  # @return [self, nil] the current context on success, or nil if cancelled
  def info_prompt(context: nil)
    context ||= 'prompt'
    if selected_prompt = choose_prompt(context:, prompt: 'Which blueprint would you like to inspect? %s')
      use_pager do |output|
        output.puts kramdown_ansi_parse(<<~EOT)
          # Prompt #{selected_prompt.name}
          ---

          #{selected_prompt.to_s}

          ---
        EOT
      end
    end
    self
  end

  # Interactively prompts the user for a name and content (optionally loading
  # from a file) to create a new prompt template.
  #
  # @return [Boolean, nil] true if the prompt was added, nil if the process was
  #   cancelled
  def add_new_prompt(context: nil)
    context ||= 'prompt'
    switch_history(:add_prompt) do
      name = determine_valid_new_name_for_prompt('to add', context:) or return

      sources       = %w[ [CLIPBOARD] [FILES] [EMPTY/MANUAL] ]
      chosen_source = choose_entry(sources, prompt: 'Where shall we source the prompt from? %s')
      chosen_source or return

      content = case chosen_source
                when '[CLIPBOARD]'
                  perform_paste_from_clipboard(edit: false)
                when '[FILES]'
                  patterns = ask?(
                    prompt: "❓ Enter file patterns to load file, C-u ⇒ new, C-c ⇒ cancel: ",
                    prefill: '**/*.{txt,md}'
                  )
                  patterns.nil? ? (return) : (patterns.present? ? load_prompt_from_file(patterns) : nil)
                else
                  nil
                end

      prompt_content = edit_text(content)
      store_prompt(name, prompt_content, context:).to_s
      true
    end
  end

  # Interactively selects an existing non-default prompt and deletes it after
  # confirmation.
  def choose_and_delete_prompt(context: nil, force: false)
    context ||= 'prompt'
    selected_prompt = choose_prompt(
      default:  force ? nil : false,
      context:,
      prompt:  'Which template has outlived its usefulness? %s'
    ) or return
    STDOUT.puts kramdown_ansi_parse(
      selected_prompt.to_s + "\n---"
    )
    confirm?(
      prompt: "🔔 Really delete the prompt #{bold{selected_prompt.name}}? (y/n) ",
      yes: /\Ay/i
    ) or return
    selected_prompt.destroy
  end

  # Interactively selects an existing prompt and allows the user to edit its
  # content via the integrated editor.
  #
  # @return [self, nil] the current context on success, or nil if cancelled
  def choose_and_edit_prompt(context: nil)
    context ||= 'prompt'
    selected_prompt = choose_prompt(context:, prompt: 'Which spell needs some fine-tuning? %s') or return
    selected_prompt.metadata['content'] = edit_text(selected_prompt.metadata['content'].to_s)
    selected_prompt.save
    self
  end

  # Duplicates an existing prompt.
  #
  # This method initiates an interactive workflow:
  # 1. Prompts the user to select a prompt to clone.
  # 2. Displays the content of the selected prompt for verification.
  # 3. Requests a new name for the duplicate, validating that it does
  #    not already exist in the database.
  # 4. Creates and saves the new prompt record using the {OllamaChat::Database::Duplicatable} mixin.
  #
  # @return [self, nil] the current context on success, or nil if the user
  #   cancelled the operation or no prompt was selected.
  def duplicate_prompt(context: nil)
    context ||= 'prompt'
    selected_prompt = choose_prompt(context:, prompt: 'Which prompt shall be the basis for a new one? %s') or return
    STDOUT.puts kramdown_ansi_parse(
      selected_prompt.to_s + "\n---"
    )
    name = nil
    loop do
      name = ask?(
        prompt: "❓ Enter new prompt name to duplicate as, C-c ⇒ cancel: "
      )
      if name.nil?
        STDOUT.puts "Cancelled."
        return nil
      end
      if prompt(name, context:)
        STDOUT.puts "Prompt named #{bold{name}} already exists."
      else
        break
      end
    end
    duplicated_prompt = selected_prompt.duplicate
    duplicated_prompt.name = name
    duplicated_prompt.metadata['default'] = false
    duplicated_prompt.save
    self
  end

  # Interactively imports a prompt from a file.
  #
  # The process follows these steps:
  # 1. Resolves the source file path (either using the provided filename or
  #    prompting the user to choose one).
  # 2. Prompts for a unique name for the new prompt via `determine_valid_new_name_for_prompt`.
  # 3. Reads the file content and stores it in the database.
  #
  # @param filename [String, Pathname, nil] the path to the file to import,
  #   or nil to trigger interactive file selection.
  # @return [self, nil] the current context on success, or nil if the
  #   import was cancelled.
  def import_prompt(filename, context: nil)
    context ||= 'prompt'
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
      STDOUT.puts "Cancelled."
      return
    end
    prompt_name = determine_valid_new_name_for_prompt('to import', context:) or return
    prompt_content = filename.read
    store_prompt(prompt_name, prompt_content, context:)
    STDOUT.puts "Imported prompt as #{prompt_name.inspect}."
    self
  end

  # Interactively exports a prompt to a specified file.
  #
  # The process follows these steps:
  # 1. Prompts the user to select a prompt via `choose_prompt`.
  # 2. Displays the prompt's current content to the terminal.
  # 3. Prompts for a destination filename via
  #   `determine_valid_output_filename`.
  # 4. Writes the prompt content to the chosen file.
  #
  # @return [self, nil] returns self if the export was successful, or nil if
  #   the process was cancelled during prompt selection or filename entry.
  def export_prompt(context: nil)
    context ||= 'prompt'
    selected_prompt = choose_prompt(context:, prompt: 'Which template are you exporting to disk? %s') or return
    STDOUT.puts kramdown_ansi_parse(
      selected_prompt.to_s + "\n---"
    )
    filename = determine_valid_output_filename('to write to') or return
    filename.write(selected_prompt.to_s)
    STDOUT.puts "Prompt #{selected_prompt.name.inspect} was exported as #{filename.to_path.inspect}?"
    self
  end

  # Aggregates the current conversation history into a single string for
  # context-aware generation.
  #
  # Each message is formatted as "Sender Name: Message Content",
  # skipping messages that contain no content.
  #
  # @return [String] The flattened conversation history.
  def prepare_conversation_history
    messages.each_message.inject('') do |result, message|
      message_content = message.content.full? or next result
      sender_name     = sender_name_displayed(message, template: false)
      result << "%s: %s" % [ sender_name, message_content ]
    end
  end

  # Interactively generates follow-up prompt suggestions based on the current
  # session.
  #
  # This method constructs a prompt containing the conversation history and an
  # instruction (either selected from a template or provided manually) and
  # requests a generation from the AI model. The resulting suggestions are then
  # opened in the editor for final refinement before being returned.
  #
  # @param edit [Boolean] If true, allows the user to write a custom suggestion
  #   instruction on the fly; otherwise, prompts the user to pick a template.
  #
  # @return [String, nil] The refined suggestion text, or nil if the process
  #   was cancelled.
  def suggest_prompts(edit: false)
    instruction = nil
    if edit
      # Let the user write a suggestion instruction on the fly
      instruction = edit_text('').full? or return
    else
      # Let the user pick a prompt template (e.g., suggest_coding, suggest_roleplaying)
      instruction = choose_prompt(
        prompt: 'Which suggestion strategy shall we employ? %s',
        context: 'suggest'
      ) or return
    end

    # Build the context by gathering all current conversation messages
    history     = prepare_conversation_history
    full_prompt = <<~EOT
      Conversation History:
      #{history}

      Instruction:
      #{instruction}
    EOT

    # Execute a silent chat oneshot call (doesn't add to history)
    suggestions  = generate(prompt: full_prompt).full? or return

    # Pass the AI's suggestions through the editor for final refinement
    edit_text(suggestions)
  end

  # Lists all prompt templates in the database, indicating which are defaults
  # and showing a truncated preview of their content.
  #
  # @return [Array] the result of the prompt mapping
  def list_prompts(context: nil)
    context ||= 'prompt'
    favs = all_favourited(context)
    each_prompt(context:).sort_by(&:name).map do |p|
      default = p.metadata['default'] ? '⛭' : '✎'
      start   = '%s %s' % [ default, bold { p.name } ]
      start   = prefix_favourite(start, favs[p.name])
      content = p.to_s.inspect[1..-2]
      content = Kramdown::ANSI::Width.truncate(
        content, length: 0.9 * (Tins::Terminal.columns - start.size)
      )
      STDOUT.print start
      STDOUT.puts ' %s' % italic { content }
    end
  end

  # Resets a prompt's content to the default value defined in the configuration.
  #
  # @param name [String, Symbol] the name of the prompt to reset
  # @return [Boolean, nil] true if the prompt was reset, false if no default was found
  def reset_prompt_to_default(name, context: nil)
    context ||= 'prompt'
    if content = config.prompts.prompt[name.to_s]
      store_prompt(name, content, context:)
      true
    end
  end

  private

  # Helper to wrap a prompt name with its favourite status for the UI.
  #
  # @param name [String] the name of the prompt
  # @param favourited [Boolean] whether the prompt is marked as a favourite
  # @return [SearchUI::Wrapper] a wrapper containing the original name and the
  #   decorated display string
  def prompt_with_favourite(name, favourited)
    display = prefix_favourite(name, favourited)
    SearchUI::Wrapper.new(name, display:)
  end

  # Interactively determines a unique name for a new prompt, ensuring it
  # does not conflict with existing prompts in the database.
  #
  # The method loops until the user either provides a name that is not
  # currently in use or cancels the operation.
  #
  # @param action [String] The action being performed (e.g., 'to import'
  #   or 'to duplicate as'), used to provide context in the user prompt.
  # @return [String, nil] The validated unique prompt name, or nil if
  #   the operation was cancelled.
  def determine_valid_new_name_for_prompt(action, context: nil)
    context ||= 'prompt'
    prompt_name = nil
    loop do
      prompt_name = ask?(
        prompt: "❓ Enter new prompt name #{action}, C-c ⇒ cancel: "
      )
      if prompt_name.nil?
        STDOUT.puts "Cancelled."
        return nil
      end
      if prompt(prompt_name, context:)
        STDOUT.puts "Prompt named #{bold{prompt_name}} already exists."
      else
        break
      end
    end
    prompt_name
  end
end
