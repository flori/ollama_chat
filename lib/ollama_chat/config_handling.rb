# Provides functionality for handling configuration files and settings for
# OllamaChat. It loads configuration from YAML files, supports environment
# variable overrides, and offers methods to read and write configuration data.
# The module also ensures default values are set and validates configuration
# structure.
module OllamaChat::ConfigHandling
  extend Tins::Concern

  class_methods do
    # The config attribute accessor provides read and write access to the
    # configuration object associated with this instance.
    attr_accessor :config
  end

  # The config method returns the configuration object associated with the
  # class.
  #
  # @return [ ComplexConfig::Settings ] the configuration instance
  def config
    self.class.config
  end

  private

  # The config= method assigns a new configuration object to the class.
  #
  # @param config [ ComplexConfig::Settings ] the configuration object to be set
  def config=(config)
    self.class.config = config
  end

  # The display_config method renders the configuration and displays it using a
  # pager. It determines an appropriate pager command based on environment
  # variables and available system commands, then uses Kramdown::ANSI::Pager to
  # show the formatted configuration output.
  def display_config
    command  = OC::PAGER?
    rendered = config.to_s
    Kramdown::ANSI::Pager.pager(
      lines: rendered.count(?\n),
      command:
    ) do |output|
      output.puts rendered
    end
  end

  # The fix_config method handles configuration file errors by informing the
  # user about the exception and prompting them to fix it. It then executes a
  # diff tool to compare the current config file with the default one.
  # This method exits the program after handling the configuration error.
  #
  # @param exception [Exception] the exception that occurred while reading
  #   the config file
  def fix_config(exception)
    save_conversation(OC::XDG_CACHE_HOME + 'backup.json')
    STDOUT.puts "When reading the config file, a #{exception.class} "\
      "exception was caught: #{exception.message.inspect}"
    unless diff_tool = OC::DIFF_TOOL?
      exit 1
    end
    if ask?(prompt: 'Do you want to fix the config? (y/n) ') =~ /\Ay/i
      system Shellwords.join([
        diff_tool,
        @ollama_chat_config.filename,
        @ollama_chat_config.default_config_path,
      ])
      exit 0
    else
      exit 1
    end
  end

  # Edit the current configuration file in the editor defined by the
  # environment variable `EDITOR`.
  #
  # 1. Looks up the editor command via `OC::EDITOR`.
  #    If the value is `nil` or empty, it prints an error message to
  #    STDERR and returns immediately.
  # 2. Invokes the editor with the path to the active configuration
  #    file (`@ollama_chat_config.filename`). The editor is launched via
  #    `system` so that the process inherits the current terminal,
  #    allowing in‑place editing.
  # 3. If editing was successful, prompts the user to restart
  #    `ollama_chat` if desired.
  def edit_config
    unless editor = OC::EDITOR?
      STDERR.puts "Need the environment variable var EDITOR defined to use an editor"
      return
    end
    result = system Shellwords.join([ editor, @ollama_chat_config.filename ])
    if result
      if ask?(prompt: "Do you want to restart #{progname}? (y/n) ") =~ /\Ay/i
        save_conversation(OC::XDG_CACHE_HOME + 'backup.json')
        exec($0, *ARGV)
      end
    else
      STDERR.puts "Editor returned a non-zero status!"
    end
  end
end
