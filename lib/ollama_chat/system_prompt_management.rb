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
    favs = all_favourited('system')
    each_prompt(context: 'system').sort_by(&:name).map do |p|
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

  # Resolves the currently active system prompt name to its raw text content.
  #
  # If the current system prompt is set to 'model_default', this method
  # retrieves the default prompt associated with the loaded model. Otherwise,
  # it fetches the content of the specifically named system prompt from the
  # database.
  #
  # The returned string represents the base template; any dynamic placeholders
  # (e.g., %{persona} and %{runtime_info}) are nullified to ensure only the raw
  # structure is returned.
  #
  # @return [String] The raw text content of the active system prompt.
  def raw_system_prompt
    system_name =  current_system_prompt_name
    if system_name == 'model_default'
      model_default_system_prompt.to_s
    else
      prompt(system_name, context: 'system').to_s
    end % { persona: nil, runtime_info: nil }
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
      ('default' if prompt(:default, context: 'system')) ||
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
    chosen = choose_entry(
      prompts,
      prompt: 'Which governing law shall we enact? %s'
    )
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
end
