require 'pathname'

class OllamaChat::OllamaChatConfig
  include ComplexConfig
  include FileUtils

  DEFAULT_CONFIG_PATH = Pathname.new(__FILE__).dirname.
    join('ollama_chat_config/default_config.yml')

  DEFAULT_CONFIG = File.read(DEFAULT_CONFIG_PATH)

  # The initialize method sets up the configuration file path and ensures the
  # cache directory exists.
  # It attempts to load configuration from the specified filename or uses a
  # default path.
  # If the configuration file is missing and the default path is used, it
  # creates the necessary directory structure and writes a default
  # configuration file.
  #
  # @param filename [ String, nil ] the path to the configuration file
  def initialize(filename = nil)
    @filename = filename || default_path
    unless File.directory?(cache_dir_path)
      mkdir_p cache_dir_path.to_s
    end
    @config = Provider.config(@filename, '⚙️')
    retried = false
  rescue ConfigurationFileMissing
    if @filename == default_path && !retried
      retried = true
      mkdir_p config_dir_path.to_s
      File.secure_write(default_path, DEFAULT_CONFIG)
      retry
    else
      raise
    end
  end

  # The filename reader returns the name of the file associated with this instance.
  attr_reader :filename

  # The config reader returns the configuration object for the chat instance.
  #
  # @return [ ComplexConfig::Settings ] the configuration object
  attr_reader :config

  # The default_config_path method returns the path to the default
  # configuration file.
  #
  # @return [ String ] the path to the default configuration file
  def default_config_path
    DEFAULT_CONFIG_PATH
  end

  # The default_path method constructs the full path to the default
  # configuration file.
  #
  # @return [ Pathname ] a Pathname object representing the path to the
  # config.yml file within the configuration directory
  def default_path
    config_dir_path + 'config.yml'
  end

  # The config_dir_path method returns the path to the ollama_chat
  # configuration directory by combining the XDG config home directory with the
  # 'ollama_chat' subdirectory.
  #
  # @return [ Pathname ] the pathname object representing the configuration
  # directory
  def config_dir_path
    XDG.new.config_home + 'ollama_chat'
  end

  # The cache_dir_path method returns the path to the ollama_chat cache
  # directory within the XDG cache home directory.
  #
  # @return [ Pathname ] the pathname object representing the cache directory path
  def cache_dir_path
    XDG.new.cache_home + 'ollama_chat'
  end

  # The database_path method constructs the full path to the documents database
  # file by joining the cache directory path with the filename 'documents.db'.
  #
  # @return [ Pathname ] the full path to the documents database file
  def database_path
    cache_dir_path + 'documents.db'
  end

  # The diff_tool method returns the preferred diff tool command.
  # It checks for the DIFF_TOOL environment variable and falls back to
  # 'vimdiff' if not set.
  #
  # @return [ String ] the command name of the diff tool to be used
  def diff_tool
    ENV.fetch('DIFF_TOOL', 'vimdiff')
  end
end
