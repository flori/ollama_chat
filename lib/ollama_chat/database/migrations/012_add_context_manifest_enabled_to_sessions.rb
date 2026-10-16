Sequel.migration do
  change do
    add_column :sessions, :context_manifest_enabled, :boolean,
      null: false, default: false
  end
end
