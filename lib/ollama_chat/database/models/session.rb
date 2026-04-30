# Represents a persistent chat session in the database, managing the
# configuration, state, and message history for an individual chat interaction.
#
# This model utilizes Sequel plugins to handle timestamps, object touching, and
# the JSON serialization of complex attributes such as `tools_default_enabled`
# and `model_options`.
class OllamaChat::Database::Models::Session < Sequel::Model(OllamaChat::DB)
  include OllamaChat::Database::SessionLocking
  include OllamaChat::Database::Duplicatable

  plugin :timestamps, update_on_create: true
  plugin :touch
  plugin :serialization, :json, :tools_default_enabled
  plugin :serialization, :json, :model_options
  plugin :validation_helpers

  # Validates the session instance.
  #
  # Ensures that the `name` and essential timestamps (`updated_at`, `created_at`)
  # are present to ensure session age calculations can be performed without
  # Nil errors.
  def validate
    super
    validates_presence :name
    validates_unique :name
    validates_presence :updated_at
    validates_presence :created_at
  end

  # Calculates the age of the session based on the last update timestamp.
  #
  # @param now [Time] the reference time for the age calculation (defaults to Time.now)
  #
  # @return [Tins::Duration] the duration since the session was last updated
  def age(now: Time.now)
    Tins::Duration.new(updated_at ? now - updated_at : 0)
  end

  # @!attribute [v] id
  #   @return [Integer] The primary key for the session.
  #
  # @!attribute [v] name
  #   @return [String] The unique name of the session.
  #
  # @!attribute [v] current_model
  #   @return [String, nil] The name of the model currently active in this session.
  #
  # @!attribute [v] current_collection
  #   @return [String, nil] The name of the currently active document collection.
  #
  # @!attribute [v] default_persona_name
  #   @return [String, nil] The identifier of the persona set as default for this session.
  #
  # @!attribute [v] current_system_prompt
  #   @return [String, nil] The text of the current system prompt.
  #
  # @!attribute [v] tools_enabled
  #   @return [Boolean] Indicates whether tool calling is enabled.
  #
  # @!attribute [v] tools_default_enabled
  #   @return [String, nil] A JSON-serialized string containing default settings for tools.
  #
  # @!attribute [v] think_mode
  #   @return [String] The current thinking mode (must be one of `THINK_MODE_STATES`).
  #
  # @!attribute [v] think_loud_enabled
  #   @return [Boolean] Whether thinking annotations are displayed in the output.
  #
  # @!attribute [v] embedding_enabled
  #   @return [Boolean] Whether embedding/RAG capabilities are enabled.
  #
  # @!attribute [v] document_policy
  #   @return [String] The policy for handling document references (must be one of `DOCUMENT_POLICY_STATES`).
  #
  # @!attribute [v] runtime_info_enabled
  #   @return [Boolean] Whether runtime information is displayed during the session.
  #
  # @!attribute [v] think_strip_enabled
  #   @return [Boolean] Whether thinking content should be stripped from the final output.
  #
  # @!attribute [v] markdown_enabled
  #   @return [Boolean] Whether Markdown rendering is enabled for the session.
  #
  # @!attribute [v] stream_enabled
  #   @return [Boolean] Whether the response should be streamed.
  #
  # @!attribute [v] location_enabled
  #   @return [Boolean] Whether location-based information is enabled.
  #
  # @!attribute [v] voice_enabled
  #   @return [Boolean] Whether voice output is enabled.
  #
  # @!attribute [v] current_voice
  #   @return [String] The name of the voice currently in use.
  #
  # @!attribute [v] working_directory
  #   @return [String] The directory used as the working context for this session.
  #
  # @!attribute [v] locked_by_pid
  #   @return [Integer, nil] The process ID that currently holds a lock on this session.
  #
  # @!attribute [v] model_options
  #   @return [String, nil] A JSON-serialized string containing model-specific options.
  #
  # @!attribute [v] messages
  #   @return [String] The full conversation history, stored in JSONL format.
  #
  # @!attribute [v] created_at
  #   @return [Time, nil] The timestamp when the session was created.
  #
  # @!attribute [v] updated_at
  #   @return [Time, nil] The timestamp of the last update to the session.

  # The with_defaults method is a factory method that initializes a new
  # Session model instance with a set of default values derived
  # from the
  # @param chat [OllamaChat::Chat] the active chat instance used to
  #   extract
  # @return [OllamaChat::Database::Models::Session] a new session
  #   instance with default attributes
  def self.with_defaults(chat)
    tools_default_enabled =
      chat.config.tools.functions.to_h.
      each_with_object({}) { |(name, f), h| h[name.to_s] = f[:default] }
    current_model = chat.initial_model
    model_options = chat.get_stored_model_options(current_model)
    attributes = {
      name:                  "New Session #{Tins::Token.new}",
      current_model:         ,
      current_collection:    chat.initial_collection,
      default_persona_name:  chat.initial_persona_name,
      current_system_prompt: chat.initial_system_prompt,
      tools_enabled:         chat.config.tools.enabled,
      tools_default_enabled: ,
      think_mode:            chat.config.think.mode,
      think_loud_enabled:    chat.config.think.loud,
      embedding_enabled:     chat.config.embedding.enabled,
      document_policy:       chat.config.document_policy,
      runtime_info_enabled:  chat.config.runtime_info.enabled,
      think_strip_enabled:   chat.config.think.strip,
      markdown_enabled:      chat.config.markdown,
      stream_enabled:        chat.config.stream,
      location_enabled:      chat.config.location.enabled,
      voice_enabled:         chat.config.voice.enabled,
      model_options:         ,
      current_voice:         chat.config.voice.default,
      working_directory:     Dir.pwd,
      messages:              '',
    }
    new(attributes)
  end
end
