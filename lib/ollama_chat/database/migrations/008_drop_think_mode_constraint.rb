# Removes the `think_mode` CHECK constraint from the `sessions` table.
#
# The set of valid think modes is model-dependent and evolving upstream
# (e.g., `max` was only added mid-2026, and numeric token budgets are
# under discussion), so the schema should not pin a fixed vocabulary.
# State validation is handled in Ruby via
# `OllamaChat::ThinkControl::THINK_MODE_STATES` and the state selectors.
#
# SQLite cannot alter CHECK constraints in place, so the table is rebuilt
# using the same shadow-table pattern as
# `004_add_profile_to_model_options.rb`.
Sequel.migration do
  up do
    create_table(:sessions_new) do
      primary_key :id
      String :name, null: false
      String :current_model
      String :current_collection
      String :default_persona_name
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
      Text :working_directory
      Integer :locked_by_pid
      Text :model_options
      Text :messages, null: false
      Text :links, null: false, default: ''
      Text :history, null: false, default: ''
      String :context_format, null: false, default: 'JSON'
      Time :created_at
      Time :updated_at
      unique [:name]

      constraint(
        :document_policy,
        document_policy: %w[ ignoring embedding importing summarizing ]
      )
    end

    source = from(:sessions).select(
      :id, :name, :current_model, :current_collection,
      :default_persona_name, :current_system_prompt,
      :tools_enabled, :tools_default_enabled, :think_mode,
      :think_loud_enabled, :embedding_enabled, :document_policy,
      :runtime_info_enabled, :think_strip_enabled,
      :markdown_enabled, :stream_enabled, :location_enabled,
      :voice_enabled, :current_voice, :working_directory,
      :locked_by_pid, :model_options, :messages, :links,
      :history, :context_format, :created_at, :updated_at
    )
    from(:sessions_new).insert(source)

    drop_table(:sessions)
    rename_table(:sessions_new, :sessions)
  end

  down do
    # Restores the original `think_mode` constraint. All rows that
    # predate the up-migration satisfy it; any newer value (e.g. `max`)
    # would fail the insert, which is the desired loud failure on
    # rollback.
    create_table(:sessions_old) do
      primary_key :id
      String :name, null: false
      String :current_model
      String :current_collection
      String :default_persona_name
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
      Text :working_directory
      Integer :locked_by_pid
      Text :model_options
      Text :messages, null: false
      Text :links, null: false, default: ''
      Text :history, null: false, default: ''
      String :context_format, null: false, default: 'JSON'
      Time :created_at
      Time :updated_at
      unique [:name]

      constraint(
        :think_mode,
        think_mode: %w[ disabled enabled low medium high ]
      )
      constraint(
        :document_policy,
        document_policy: %w[ ignoring embedding importing summarizing ]
      )
    end

    source = from(:sessions).select(
      :id, :name, :current_model, :current_collection,
      :default_persona_name, :current_system_prompt,
      :tools_enabled, :tools_default_enabled, :think_mode,
      :think_loud_enabled, :embedding_enabled, :document_policy,
      :runtime_info_enabled, :think_strip_enabled,
      :markdown_enabled, :stream_enabled, :location_enabled,
      :voice_enabled, :current_voice, :working_directory,
      :locked_by_pid, :model_options, :messages, :links,
      :history, :context_format, :created_at, :updated_at
    )
    from(:sessions_old).insert(source)

    drop_table(:sessions)
    rename_table(:sessions_old, :sessions)
  end
end
