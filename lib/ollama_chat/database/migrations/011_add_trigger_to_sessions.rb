Sequel.migration do
  change do
    alter_table :sessions do
      add_column :trigger, :text
    end
  end
end
