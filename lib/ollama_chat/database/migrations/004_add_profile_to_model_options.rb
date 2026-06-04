# This migration implements a "shadow table" pattern to update the unique constraint
# in SQLite, as SQLite does not support dropping existing UNIQUE constraints.
Sequel.migration do
  up do
    # 1. Create the new table with the desired schema and composite index
    create_table(:model_options_new) do
      primary_key :id
      String :model_name, null: false
      String :profile, null: false, default: 'default'
      Text :options, null: false
      Time :created_at
      Time :updated_at
      unique [:model_name, :profile]
    end

    # 2. Migrate existing data, assigning all current records to the 'default' profile
    source = from(:model_options).select(
      :id,
      :model_name,
      Sequel.lit("'default'").as(:profile),
      :options,
      :created_at,
      :updated_at
    )
    from(:model_options_new).insert(source)

    # 3. Swap the tables
    drop_table(:model_options)
    rename_table(:model_options_new, :model_options)
  end

  down do
    # Reverting from a composite key to a single unique key is potentially destructive.
    # We'll preserve only the 'default' profile records to maintain the old constraint.
    create_table(:model_options_old) do
      primary_key :id
      String :model_name, null: false
      Text :options, null: false
      Time :created_at
      Time :updated_at
      unique [:model_name]
    end

    source = from(:model_options).where(profile: 'default').select(
      :id,
      :model_name,
      :options,
      :created_at,
      :updated_at
    )
    from(:model_options_old).insert(source)

    drop_table(:model_options)
    rename_table(:model_options_old, :model_options)
  end
end
