# Provides advanced system prompt management capabilities for the OllamaChat
# session.
#
# This module encapsulates the logic for initializing, changing, and loading
# system prompts, allowing for dynamic and interactive configuration within the
# chat lifecycle.
module OllamaChat::SystemPromptManagement
  # Sets up the system prompt for the chat session.
  #
  # This method determines whether to use a default system prompt or a custom
  # one specified via command-line options. If a custom system prompt is
  # provided with a regexp selector (starting with ?), it invokes the
  # change_system_prompt method to handle the selection. Otherwise, it
  # retrieves the system prompt from a file or uses the default value, then
  # sets it in the message history.
  def setup_system_prompt
    default = config.system_prompts.default? || @model_metadata.system
    if @opts[?s] =~ /\A\?/
      change_system_prompt(default, system: @opts[?s])
    else
      system = OllamaChat::Utils::FileArgument.get_file_argument(@opts[?s], default:)
      system.present? and messages.set_system_prompt(system)
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

  # Loads a system prompt from a file selected via an interactive file chooser.
  #
  # @param patterns [ Array<String> ] file patterns to filter the selection (e.g., ['*.txt', '*.md'])
  def load_system_prompt_from_file(patterns = nil)
    patterns = Array(patterns.full? || '**/*.{txt,md}')
    filename = choose_filename(patterns)

    if filename&.exist?
      content = filename.read
      @messages.set_system_prompt(content)
      STDOUT.puts "Successfully loaded system prompt from: #{filename}"
    else
      STDOUT.puts "No valid file selected or file does not exist."
    end
  end
end
