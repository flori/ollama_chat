Sequel.migration do
  change do
    alter_table(:sessions) do
      add_column :links, :text, null: false, default: ''
    end
  end
end
