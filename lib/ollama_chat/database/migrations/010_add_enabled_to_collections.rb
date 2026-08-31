Sequel.migration do
  change do
    alter_table :collections do
      add_column :enabled, :boolean, default: true, null: false
    end
  end
end
