# Provides methods for retrieving and iterating over prompt templates
# stored in the database.
#
# This module is designed to be mixed into the Chat class, allowing it to
# access prompt overrides stored in the database using the `models` helper.
module OllamaChat::PromptHandling
  # Retrieves a specific system prompt by name from the 'system_prompt'
  # context.
  #
  # @param name [String, Symbol] the name of the system prompt to retrieve
  # @return [OllamaChat::Database::Models::Prompt, nil] the prompt model
  #   instance or nil if not found
  def system_prompt(name)
    models::Prompt.where(context: 'system_prompt', name: name.to_s).first
  end

  # Retrieves a specific prompt by name from the 'prompt' context.
  #
  # @param name [String, Symbol] the name of the prompt to retrieve
  # @return [OllamaChat::Database::Models::Prompt, nil] the prompt model
  #   instance or nil if not found
  def prompt(name)
    models::Prompt.where(context: 'prompt', name: name.to_s).first
  end

  private

  # Iterates over all prompts in the 'prompt' context.
  #
  # @yield [prompt] yields each prompt model instance
  # @return [Enumerator] an enumerator if no block is given
  def each_prompt(default: nil, &block)
    block or return enum_for(__method__, default:)
    prompts = models::Prompt.where(context: 'prompt')
    case default
    when true
      prompts = prompts.where(Sequel.lit("metadata ->> '$.default' = 1"))
    when false
      prompts = prompts.where(Sequel.lit(<<~SQL))
        metadata ->> '$.default' = 0 OR metadata ->> '$.default' IS NULL
      SQL
    end
    prompts.all.each(&block)
  end

  # Deletes a prompt by name from the 'prompt' context if it is not a default
  # prompt.
  #
  # @param name [String, Symbol] the name of the prompt to delete
  # @return [Boolean] true if deleted, false otherwise
  def delete_prompt(name)
    if found = prompt(name) and !found.metadata['default']
      found.destroy
      return true
    end
    false
  end

  # Stores a prompt in the 'prompt' context.
  #
  # @param name [String, Symbol] the name of the prompt
  # @param content [String] the content of the prompt
  # @return [OllamaChat::Database::Models::Prompt] the saved prompt model
  #   instance
  def store_prompt(name, content)
    write_prompt('prompt', name, content)
  end

  # Deletes a system prompt by name from the 'system_prompt' context if it is
  # not a default prompt.
  #
  # @param name [String, Symbol] the name of the system prompt to delete
  # @return [Boolean] true if deleted, false otherwise
  def delete_system_prompt(name)
    if found = system_prompt(name) and !found.metadata['default']
      found.destroy
      return true
    end
    false
  end

  # Stores a system prompt in the 'system_prompt' context.
  #
  # @param name [String, Symbol] the name of the system prompt
  # @param content [String] the content of the system prompt
  # @return [OllamaChat::Database::Models::Prompt] the saved system prompt
  #   model instance
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

  # Creates or updates a prompt in the specified context.
  #
  # @param context [String] the context (e.g., 'prompt' or 'system_prompt')
  # @param name [String] the name of the prompt
  # @param content [String] the content of the prompt
  # @return [OllamaChat::Database::Models::Prompt] the created or updated
  #   prompt model instance
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

  # Interactively selects a file based on patterns and reads its content.
  #
  # @param patterns [String, Array<String>] file patterns to filter the
  #   selection
  # @return [String, nil] the content of the file or nil if no file was
  #   selected or doesn't exist
  def load_prompt_from_file(patterns = nil)
    patterns = Array(patterns.full? || '**/*.{txt,md}')
    filename = choose_filename(patterns)

    filename.read if filename&.exist?
  end
end
