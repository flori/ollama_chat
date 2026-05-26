Sequel.migration do
  change do
    alter_table(:sessions) do
      add_column :history, :text, null: false, default: ''
    end
  end
end
