Sequel.migration do
  change do
    create_table(:model_options) do
      primary_key :id
      String :model_name, null: false
      Text :options, null: false
      Time :created_at
      Time :updated_at
      unique [:model_name]
    end

    create_table(:favourites) do
      primary_key :id
      String :context, null: false
      String :name, null: false
      String :metadata, text: true
      Time :created_at
      Time :updated_at
      unique [:context, :name]
    end

    create_table(:sessions) do
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

    create_table(:prompts) do
      primary_key :id
      String :context, null: false
      String :name, null: false
      String :metadata, text: true
      Time :created_at
      Time :updated_at
      unique [:context, :name]
    end
  end
end
