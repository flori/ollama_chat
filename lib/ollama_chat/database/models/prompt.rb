# Represents a prompt template stored in the database, allowing for
# dynamic overrides of default configuration prompts.
#
# This model stores prompts with a context (e.g., 'prompt' or 'system_prompt')
# and a name, with the actual content residing in a serialized JSON metadata column.
class OllamaChat::Database::Models::Prompt < Sequel::Model(OllamaChat::DB)
  include Duplicatable

  plugin :timestamps
  plugin :serialization, :json, :metadata
  plugin :validation_helpers

  # Validates the prompt template.
  #
  # Ensures that both the `context` and `name` are present.
  def validate
    super
    validates_presence :context
    validates_presence :name
  end

  # @!attribute [v] id
  #   @return [Integer] The primary key for the prompt entry.
  #
  # @!attribute [v] context
  #   @return [String] The context of the prompt (e.g., 'prompt' or 'system_prompt').
  #
  # @!attribute [v] name
  #   @return [String] The name of the prompt.
  #
  # @!attribute [v] metadata
  #   @return [Hash, nil] A JSON-serialized hash containing prompt metadata,
  #     including the actual content.
  #
  # @!attribute [v] created_at
  #   @return [Time, nil] The timestamp when the prompt was created.
  #
  # @!attribute [v] updated_at
  #   @return [Time, nil] The timestamp of the last update to the prompt.

  # Returns the actual prompt text stored within the metadata JSON.
  #
  # @return [String] the prompt content
  def to_s
    metadata['content'].to_s
  end

  # Hook to clean up associated favourites when a prompt is destroyed.
  #
  # This ensures that we don't leave orphaned favourite entries in the
  # database when the underlying prompt is removed.
  def after_destroy
    super
    OllamaChat::Database::Models::Favourite.
      where(context: context, name: name).
      destroy
  end

  # Seeds the prompt table from the provided chat configuration.
  #
  # This method iterates through both general and system prompts in the
  # chat configuration, ensuring that every default prompt has a
  # corresponding record in the database for later override.
  #
  # @param chat [OllamaChat::Chat] the chat instance providing the configuration
  def self.seed(chat)
    chat.config.prompts.each do |name, content|
      where(
        context: 'prompt',
        name:    name.to_s,
      ).first and next
      create(
        context:  'prompt',
        name:     name.to_s,
        metadata: { default: true, content: }.stringify_keys_recursive
      )
    end
    chat.config.system_prompts.each do |name, content|
      where(
        context: 'system_prompt',
        name:    name.to_s,
      ).first and next
      create(
        context:  'system_prompt',
        name:     name.to_s,
        metadata: { default: true, content: }.stringify_keys_recursive
      )
    end
  end
end
