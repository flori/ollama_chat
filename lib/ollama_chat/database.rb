# The OllamaChat::Database module is responsible for managing the
# application's persistence layer, including the initialization
# of the database connection and the dynamic loading of models.
module OllamaChat::Database
  # This module serves as the primary namespace and organized container for all
  # Sequel-based database models used throughout the application.
  #
  # This namespace acts as a central registry, grouping all persistent
  # entities—such as `Session`, `Favourite`, and `ModelOptions`—into a
  # single, logical structure. This organization ensures that all data
  # models are easily discoverable and logically separated from the
  # database initialization logic.
  module Models
  end

  # Bootstraps the database layer by establishing a connection, running
  # migrations, and dynamically loading all models.
  #
  # This method performs the following sequence:
  # 1. Identifies the SQLite database path within the XDG state directory.
  # 2. Establishes a connection using `Sequel` and assigns it to
  #    the `OllamaChat::DB` constant.
  # 3. Executes the database migrations via
  #    `OllamaChat::Database::Models::Migrations.run`.
  # 4. Iteratively requires all Ruby files found in the
  #    `database/models/` directory, ensuring the migration file itself is skipped.
  def self.setup_models
    db_path = OC::XDG_STATE_HOME.join('settings.db').expand_path

    url = 'sqlite://' + db_path.to_path
    logger = Logger.new(OC::OLLAMA::CHAT::DATABASE_LOGFILE)
    unless OllamaChat.const_defined?('DB')
      OllamaChat.const_set('DB', Sequel.connect(url, logger:))
    end

    # Load and apply migrations first
    require_relative 'database/migrations'
    OllamaChat::Database::Models::Migrations.run(OllamaChat::DB)

    # Load the rest of the models
    Pathname.new(__dir__).glob('database/models/*.rb').each do |file|
      next if file.basename.to_s == 'migrations.rb'
      require file
    end
  end
end
