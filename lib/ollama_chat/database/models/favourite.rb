# Represents a user-defined favourite entry within a specific context (e.g., a
# model).
#
# This model provides a mechanism to persist preferred items, such as favourite
# models, by storing their name and an associated JSON-serialized metadata
# hash. It utilizes Sequel plugins for managing timestamps and handling JSON
# serialization for the `metadata` attribute.
class OllamaChat::Database::Models::Favourite < Sequel::Model(OllamaChat::DB)

  plugin :timestamps, update_on_create: true
  plugin :serialization, :json, :metadata
  plugin :validation_helpers

  # Validates the favourite entry.
  #
  # Ensures that both the `context` and `name` are present.
  def validate
    super
    validates_presence :context
    validates_presence :name
    validates_unique %i[ context name ]
  end

  # @!attribute [v] id
  #   @return [Integer] The primary key for the favourite entry.
  #
  # @!attribute [v] context
  #   @return [String] The context in which this favourite exists (e.g., 'model').
  #
  # @!attribute [v] name
  #   @return [String] The name of the favourite item.
  #
  # @!attribute [v] metadata
  #   @return [Hash, nil] A JSON-serialized hash containing additional metadata.
  #
  # @!attribute [v] created_at
  #   @return [Time, nil] The timestamp when the favourite was created.
  #
  # @!attribute [v] updated_at
  #   @return [Time, nil] The timestamp of the last update to the favourite.
end
