require 'pathname'

class OllamaChat::OllamaChatConfig
  include ComplexConfig
  include FileUtils

  DEFAULT_CONFIG = File.read(
    Pathname.new(__FILE__).dirname.join('ollama_chat_config/default_config.yml')
  )

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

  attr_reader :filename

  attr_reader :config

  def default_path
    config_dir_path + 'config.yml'
  end

  def config_dir_path
    XDG.new.config_home + 'ollama_chat'
  end

  def cache_dir_path
    XDG.new.cache_home + 'ollama_chat'
  end

  def database_path
    cache_dir_path + 'documents.db'
  end
end
