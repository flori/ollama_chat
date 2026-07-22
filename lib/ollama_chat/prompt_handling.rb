# Provides methods for retrieving and iterating over prompt templates
# stored in the database.
#
# This module is designed to be mixed into the Chat class, allowing it to
# access prompt overrides stored in the database using the `models` helper.
module OllamaChat::PromptHandling
  # Retrieves a specific prompt by name from the 'prompt' context.
  #
  # @param name [String, Symbol] the name of the prompt to retrieve
  # @return [OllamaChat::Database::Models::Prompt, nil] the prompt model
  #   instance or nil if not found
  def prompt(name, context: nil)
    context ||= 'prompt'
    models::Prompt.where(context:, name: name.to_s).first
  end

  # Iterates over all prompts in the 'prompt' context.
  #
  # @yield [prompt] yields each prompt model instance
  # @return [Enumerator] an enumerator if no block is given
  def each_prompt(context: nil, default: nil, &block)
    context ||= 'prompt'
    block or return enum_for(__method__, context:, default:)
    prompts = models::Prompt.where(context:)
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
  def delete_prompt(name, context: nil)
    context ||= 'prompt'
    if found = prompt(name, context:) and !found.metadata['default']
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
  def store_prompt(name, content, context: nil)
    context ||= 'prompt'
    write_prompt(name, content, context:)
  end

  # Creates or updates a prompt in the specified context.
  #
  # @param context [String] the context (e.g., 'prompt' or 'system')
  # @param name [String] the name of the prompt
  # @param content [String] the content of the prompt
  # @return [OllamaChat::Database::Models::Prompt] the created or updated
  #   prompt model instance
  def write_prompt(name, content, context: nil)
    context ||= 'prompt'
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
