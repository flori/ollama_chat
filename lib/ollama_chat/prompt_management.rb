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
  def all_prompts(default: nil)
    favs = all_favourited('prompt')
    each_prompt(default:).sort_by(&:name).map do |p|
      prompt_with_favourite(p.name, favs[p.name])
    end
  end

  # The choose_prompt method presents a menu of available prompts for
  # selection. It retrieves the list of prompt names from the database, adds an
  # '[EXIT]' option, and displays them via the Chooser utility.
  #
  # @param default [Boolean, nil] filter for default prompts (true: only
  #   defaults, false: only non-defaults)
  #
  # @return [OllamaChat::Database::Models::Prompt, nil] the selected prompt
  #   model, or nil if the user chooses '[EXIT]' or cancels the selection.
  def choose_prompt(default: nil)
    prompts = all_prompts(default: default)
    prompts.unshift('[EXIT]')
    case chosen = OllamaChat::Utils::Chooser.choose(prompts)
    when '[EXIT]', nil
      STDOUT.puts "Exiting chooser."
      return
    when *prompts
      prompt(chosen.value)
    end
  end

  # Interactively prompts the user for a name and content (optionally loading
  # from a file) to create a new prompt template.
  #
  # @return [Boolean, nil] true if the prompt was added, nil if the process was
  #   cancelled
  def add_new_prompt
    name = nil
    loop do
      name = ask?(prompt: "❓ Enter new system prompt name to add, C-c ⇒ cancel: ")
      if name.nil?
        STDOUT.puts "Canceled."
        return nil
      end
      if prompt(name)
        STDOUT.puts "Prompt named #{bold{name}} already exists."
      else
        break
      end
    end
    patterns = ask?(
      prompt: "❓ Enter file patterns to load file, C-c ⇒ cancel: ",
      prefill: '**/*.{txt,md}'
    )
    patterns.nil? and return
    content = nil
    patterns.present? and content = load_prompt_from_file(patterns)
    prompt = edit_text(content)
    store_prompt(name, prompt).to_s
    true
  end

  # Interactively selects an existing non-default prompt and deletes it after
  # confirmation.
  def choose_and_delete_prompt
    prompt = choose_prompt(default: false) or return
    STDOUT.puts kramdown_ansi_parse(
      prompt.to_s + "\n---"
    )
    confirm?(
      prompt: "🔔 Really delete the prompt #{bold{prompt.name}}? (y/n) ",
      yes: /\Ay/i
    ) or return
    prompt.destroy
  end

  # Interactively selects an existing prompt and allows the user to edit its
  # content via the integrated editor.
  #
  # @return [self, nil] the current context on success, or nil if cancelled
  def choose_and_edit_prompt
    prompt = choose_prompt or return
    prompt.metadata['content'] = edit_text(prompt.metadata['content'].to_s)
    prompt.save
    self
  end

  # Duplicates an existing prompt.
  #
  # This method initiates an interactive workflow:
  # 1. Prompts the user to select a prompt to clone.
  # 2. Displays the content of the selected prompt for verification.
  # 3. Requests a new name for the duplicate, validating that it does
  #    not already exist in the database.
  # 4. Creates and saves the new prompt record using the {Duplicatable} mixin.
  #
  # @return [self, nil] the current context on success, or nil if the user
  #   cancelled the operation or no prompt was selected.
  def duplicate_prompt
    prompt = choose_prompt or return
    STDOUT.puts kramdown_ansi_parse(
      prompt.to_s + "\n---"
    )
    name = nil
    loop do
      name = ask?(prompt: "❓ Enter new prompt name to duplicate as, C-c ⇒ cancel: ")
      if name.nil?
        STDOUT.puts "Canceled."
        return nil
      end
      if prompt(name)
        STDOUT.puts "Prompt named #{bold{name}} already exists."
      else
        break
      end
    end
    duplicated_prompt = prompt.duplicate
    duplicated_prompt.name = name
    duplicated_prompt.metadata['default'] = false
    duplicated_prompt.save
    self
  end

  # Exports a selected prompt to a specified file.
  #
  # The method first checks if the target file already exists to prevent
  # accidental overwrites. If the file is clear, it prompts the user to select
  # a prompt, displays its content for verification, and finally asks
  # for a final confirmation before writing the content to disk.
  #
  # @param filename [String, Pathname] the destination path where the
  #   prompt should be exported
  # @return [Boolean, nil] true if the prompt was exported, nil if the
  #   process was cancelled or file exists.
  def export_prompt(filename)
    filename = Pathname.new(filename)
    if filename.exist?
      STDERR.puts "File #{filename.to_path.inspect} already exists!"
      return nil
    end
    prompt = choose_prompt or return
    STDOUT.puts kramdown_ansi_parse(
      prompt.to_s + "\n---"
    )
    yes = confirm?(
      prompt: "🔔 Really export this prompt as #{filename.to_path.inspect}? (y/n) ",
      yes: /\Ay/i
    )
    if yes
      filename.write prompt
      true
    else
      STDOUT.puts "Canceled."
      nil
    end
  end

  # Lists all prompt templates in the database, indicating which are defaults
  # and showing a truncated preview of their content.
  #
  # @return [Array] the result of the prompt mapping
  def list_prompts
    favs = all_favourited('prompt')
    each_prompt.sort_by(&:name).map do |prompt|
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
end
