Sequel.migration do
  change do
    create_table :collections do
      primary_key :id
      String :name, null: false, unique: true
      Text :description, null: false
      Text :patterns # JSON-encoded array of globs
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP, null: false
      DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP, null: false
    end
  end
end
