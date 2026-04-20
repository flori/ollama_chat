# Provides administrative and interactive management for
# prompt templates stored in the database.
#
# This module handles the user-facing selection process for
# prompts, allowing users to interactively pick a prompt from
# the database.
module OllamaChat::PromptManagement
  # Retrieves all stored prompts, decorated with a heart if they are marked as favourites.
  #
  # @param default [Boolean, nil] filter for default prompts (true: only
  #   defaults, false: only non-defaults)
  #
  # @return [Array<SearchUI::Wrapper>] the list of prompts for display in a chooser
  def all_prompts(default: nil)
    favs = all_favourited('prompt')
    each_prompt(default:).sort_by(&:name).map do |p|
      prompt_with_favourite(p.name, favs[p.name])
    end
  end

  # The choose_prompt method presents a menu of available prompts for selection.
  # It retrieves the list of prompt names from the database, adds an '[EXIT]'
  # option, and displays them via the Chooser utility.
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
      name = ask?(prompt: "❓ Enter new system prompt name to add: ")
      if name.nil?
        STDOUT.puts "Canceled."
        return nil
      end
      if prompt(name)
        STDOUT.puts "System prompt named #{bold{name}} already exists."
      else
        break
      end
    end
    patterns = ask?(
      prompt: "❓ Enter file patterns to load file, C-c to cancel: ",
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

  # Lists all prompt templates in the database, indicating which are defaults
  # and showing a truncated preview of their content.
  #
  # @return [Array] the result of the prompt mapping
  def list_prompts
    fav = all_favourited('prompt')
    each_prompt.sort_by(&:name).map do |prompt|
      default = prompt.metadata['default'] ? '⛭' : '✎'
      start   = '%s %s' % [ default, bold { prompt.name } ]
      start   = prefix_favourite(start, fav[prompt.name])
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
  def prompt_with_favourite(name, favourited)
    display = prefix_favourite(name, favourited)
    SearchUI::Wrapper.new(name, display:)
  end
end
