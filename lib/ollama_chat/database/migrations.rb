# The `OllamaChat::Database::Models::Migrations` module is responsible for
# defining and executing the database schema for the application's persistent
# models.
#
# This module contains a single class method, `run`, which is invoked during
# the application's initialization to ensure the database is properly set up.
module OllamaChat::Database::Models::Migrations

  # Executes the database migrations to set up the required tables.
  #
  # @param db [Sequel::Database] The database connection to run the migrations
  #   against.
  def self.run(db)
    Sequel.extension :migration
    Sequel::Migrator.run(db, Pathname.new(__dir__) + 'migrations')
  end
end
