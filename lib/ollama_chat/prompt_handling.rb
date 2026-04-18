# Provides methods for retrieving and iterating over prompt templates
# stored in the database.
#
# This module is designed to be mixed into the Chat class, allowing it to
# access prompt overrides stored in the database using the `models` helper.
module OllamaChat::PromptHandling
  private

  # Retrieves a specific prompt by name from the 'prompt' context.
  #
  # @param name [String, Symbol] the name of the prompt to retrieve
  # @return [OllamaChat::Database::Models::Prompt, nil] the prompt model instance or nil if not found
  def prompt(name)
    models::Prompt.where(context: 'prompt', name: name.to_s).first
  end

  # Iterates over all prompts in the 'prompt' context.
  #
  # @yield [prompt] yields each prompt model instance
  # @return [Enumerator] an enumerator if no block is given
  def each_prompt(&block)
    block or return enum_for(__method__)

    models::Prompt.where(context: 'prompt').all.each(&block)
  end

  def delete_prompt(name)
    if found = prompt(name) and !found.metadata['default']
      found.destroy
      return true
    end
    false
  end

  def store_prompt(name, content)
    write_prompt('prompt', name, content, 'prompt')
  end

  # Retrieves a specific system prompt by name from the 'system_prompt' context.
  #
  # @param name [String, Symbol] the name of the system prompt to retrieve
  # @return [OllamaChat::Database::Models::Prompt, nil] the prompt model instance or nil if not found
  def system_prompt(name)
    models::Prompt.where(context: 'system_prompt', name: name.to_s).first
  end

  def delete_system_prompt(name)
    if found = system_prompt(name) and !found.metadata['default']
      found.destroy
      return true
    end
    false
  end

  def store_system_prompt(name, content)
    write_prompt('system_prompt', name, content)
  end

  # Iterates over all prompts in the 'system_prompt' context.
  #
  # @yield [prompt] yields each system prompt model instance
  # @return [Enumerator] an enumerator if no block is given
  def each_system_prompt(&block)
    block or return enum_for(__method__)

    models::Prompt.where(context: 'system_prompt').all.each(&block)
  end

  def write_prompt(context, name, content)
    obj = nil
    if found = models::Prompt.where(context:, name:).first
      found.metadata['content'] = content
      obj = found
    else
      obj = models::Prompt.create(name:, context:)
      obj.metadata = { default: false, content: }.stringify_keys_recursive
    end
    obj.tap(&:save)
  end
end
