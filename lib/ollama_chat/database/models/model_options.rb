# Sequel model for persisting model-specific configurations as a JSON blob.
# Each record is uniquely identified by its model name.
class OllamaChat::Database::Models::ModelOptions < Sequel::Model(OllamaChat::DB)
  plugin :timestamps
  plugin :serialization, :json, :options

  # @!attribute [v] id
  #   @return [Integer] The primary key for the model options entry.
  #
  # @!attribute [v] model_name
  #   @return [String] The unique name of the Ollama model these options apply to.
  #
  # @!attribute [v] options
  #   @return [String] A JSON-serialized string containing the model-specific configuration options.
  #
  # @!attribute [v] created_at
  #   @return [Time, nil] The timestamp when these options were first recorded.
  #
  # @!attribute [v] updated_at
  #   @return [Time, nil] The timestamp of the last update to these options.
end
