# Sequel model for persisting model-specific configurations as a JSON blob.
# Each record is uniquely identified by its model name.
class OllamaChat::Database::Models::ModelOptions < Sequel::Model(OllamaChat::DB)
  include OllamaChat::Database::JSONColumns

  plugin :timestamps, update_on_create: true
  json_column :options
  plugin :validation_helpers

  # Validates the model options.
  #
  # Ensures that both the `model_name` and `options` are present.
  def validate
    super
    validates_presence :model_name
    validates_unique [ :model_name, :profile ]
    validates_presence :profile
  end

  # @!attribute [v] id
  #   @return [Integer] The primary key for the model options entry.
  #
  # @!attribute [v] model_name
  #   @return [String] The unique name of the Ollama model these options apply to.
  #
  #   @return [OllamaChat::Database::GenericObject] The model-specific
  #     configuration options.
  #
  # @!attribute [v] created_at
  #   @return [Time, nil] The timestamp when these options were first recorded.
  #
  # @!attribute [v] updated_at
  #   @return [Time, nil] The timestamp of the last update to these options.
end
