# The `OllamaChat::Database::Models::Migrations` module is responsible for
# defining and executing the database schema for the application's persistent
# models.
#
# This module contains a single class method, `run`, which is invoked during
# the application's initialization to ensure the database is properly set up.
module OllamaChat::Database::Models::Migrations

  # Executes the database migrations to set up the required tables.
  #
  # This method performs the following actions:
  # 1. Creates the `model_options` table to store model-specific configuration.
  # 2. Creates the `favourites` table to manage user-defined favourites.
  # 3. Creates the `sessions` table to store session data.
  #
  # @param db [Sequel::Database] The database connection to run the migrations
  #   against.
  def self.run(db)
    db.create_table? :model_options do
      primary_key :id
      String :model_name, null: false
      Text :options, null: false
      Time   :created_at
      Time   :updated_at
      unique [ :model_name ]
    end

    db.create_table? :favourites do
      primary_key :id
      String :context, null: false
      String :name, null: false
      String :metadata, text: true
      Time   :created_at
      Time   :updated_at
      unique [ :context, :name ]
    end

    db.create_table? :sessions do
      primary_key :id
      String :name, null: false
      String :current_model
      String :current_collection
      String :default_persona_id
      String :current_system_prompt
      Boolean :tools_enabled, null: false
      Text :tools_default_enabled
      String :think_mode, null: false
      Bool :think_loud_enabled, null: false
      Bool :embedding_enabled, null: false
      String :document_policy, null: false
      Bool :runtime_info_enabled, null: false
      Bool :think_strip_enabled, null: false
      Boolean :markdown_enabled, null: false
      Boolean :stream_enabled, null: false
      Boolean :location_enabled, null: false
      Boolean :voice_enabled, null: false
      String :current_voice, null: false
      Text :model_options
      Text :messages, null: false # JSONL format
      Time :created_at
      Time :updated_at
      unique [ :name ]

      constraint(
        :think_mode,
        think_mode: OllamaChat::ThinkControl::THINK_MODE_STATES
      )

      constraint(
        :document_policy,
        document_policy: OllamaChat::Parsing::DOCUMENT_POLICY_STATES
      )
    end
  end
end
