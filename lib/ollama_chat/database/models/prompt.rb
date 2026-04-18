# Represents a prompt template stored in the database, allowing for
# dynamic overrides of default configuration prompts.
#
# This model stores prompts with a context (e.g., 'prompt' or 'system_prompt')
# and a name, with the actual content residing in a serialized JSON metadata column.
class OllamaChat::Database::Models::Prompt < Sequel::Model(OllamaChat::DB)
  plugin :timestamps
  plugin :serialization, :json, :metadata

  # Returns the actual prompt text stored within the metadata JSON.
  #
  # @return [String] the prompt content
  def to_s
    metadata['content'].to_s
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
      self.find_or_create(
        context: 'prompt',
        name: name.to_s,
      ).update(
        metadata: { content: }.stringify_keys_recursive
      )
    end
    chat.config.system_prompts.each do |name, content|
      self.find_or_create(
        context: 'system_prompt',
        name: name.to_s,
      ).update(
        metadata: { content: }.stringify_keys_recursive
      )
    end
  end
end
