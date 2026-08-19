Sequel.migration do
  change do
    create_table :app_states do
      primary_key :id
      String :key, null: false, unique: true
      Text :value # JSON-encoded payload
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP, null: false
      DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP, null: false
    end
  end
end
