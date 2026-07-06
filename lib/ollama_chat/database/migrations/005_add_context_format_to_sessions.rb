Sequel.migration do
  change do
    add_column :sessions, :context_format, String, null: false, default: 'JSON'
  end
end
