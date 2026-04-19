# Provides administrative and interactive management for
# prompt templates stored in the database.
#
# This module handles the user-facing selection process for
# prompts, allowing users to interactively pick a prompt from
# the database.
module OllamaChat::PromptManagement
  # The choose_prompt method presents a menu of available prompts for selection.
  # It retrieves the list of prompt names from the database, adds an '[EXIT]'
  # option, and displays them via the Chooser utility.
  #
  # @return [String, nil] the text of the selected prompt, or nil if
  #   the user chooses '[EXIT]' or cancels the selection.
  def choose_prompt
    prompts = each_prompt.map(&:name).sort
    prompts.unshift('[EXIT]')
    case chosen = OllamaChat::Utils::Chooser.choose(prompts)
    when '[EXIT]', nil
      STDOUT.puts "Exiting chooser."
      return
    when *prompts
      prompt(chosen)
    end
  end

  # TODO def add_new_propmpt; end

  # TODO def choose_and_edit_prompt; end

  # TODO def choose_and_delete_prompt; end
end
