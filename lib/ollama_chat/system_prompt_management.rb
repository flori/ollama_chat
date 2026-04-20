# Provides advanced system prompt management capabilities for the OllamaChat
# session.
#
# This module encapsulates the logic for initializing, changing, and loading
# system prompts, allowing for dynamic and interactive configuration within the
# chat lifecycle.
module OllamaChat::SystemPromptManagement
  # Retrieves all stored system prompts, decorated with a heart if they are marked as favourites.
  #
  # @return [Array<SearchUI::Wrapper>] the list of system prompts for display in a chooser
  def all_system_prompts
    favs = all_favourited('system_prompt')
    each_system_prompt.sort_by(&:name).map do |p|
      system_prompt_with_favourite(p.name, favs[p.name])
    end
  end

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
  # selector, and sets the selected prompt as the current system prompt for
  # the messages.
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
    prompts = all_system_prompts.select { |p| p.value =~ selector }
    if prompts.size == 1
      system = system_prompt(prompts.first.value).to_s
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
        when SearchUI::Wrapper
          system_prompt(chosen.value).to_s
        else
          default
        end
    end
    set_current_system_prompt(system)
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
    patterns = ask?(
      prompt: "❓ Enter file patterns to load file, C-c to cancel: ",
      prefill: '**/*.{txt,md}'
    )
    patterns.nil? and return
    content = nil
    patterns.present? and content = load_prompt_from_file(patterns)
    system_prompt = edit_text(content)
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
    prompt.metadata['content'] = edit_text(prompt.metadata['content'].to_s)
    prompt.save
    self
  end

  # Interactively selects an existing system prompt and deletes it after
  # confirmation.
  #
  # @return [self, nil] the current context on success, or nil if cancelled
  def choose_and_delete_system_prompt
    prompt = choose_system_prompt or return
    STDOUT.puts kramdown_ansi_parse(
      prompt.to_s + "\n---"
    )
    confirm?(
      prompt: "🔔 Really delete the system prompt #{bold{prompt.name}}? (y/n) ",
      yes: /\Ay/i
    ) or return
    prompt.destroy
    self
  end

  # Lists all stored system prompts in a formatted view, displaying their
  # default status and a truncated preview of their content.
  #
  # @return [Array] an array of the results of the printing operations
  def list_system_prompts
    fav = all_favourited('system_prompt')
    each_system_prompt.sort_by(&:name).map do |prompt|
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

  # Helper to wrap a system prompt name with its favourite status for the UI.
  def system_prompt_with_favourite(name, favourited)
    display = prefix_favourite(name, favourited)
    SearchUI::Wrapper.new(name, display:)
  end
end
