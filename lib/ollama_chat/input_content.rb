require 'tempfile'

# A module that provides input content processing functionality for OllamaChat.
#
# The InputContent module encapsulates methods for reading and returning
# content from selected files, selecting files from a list of matching files,
# and collecting project context using the context_spook library. It supports
# interactive file selection and context collection for enhancing chat
# interactions with local or remote content.
module OllamaChat::InputContent
  # The input method reads and returns the content of a selected file.
  #
  # This method searches for files matching the given pattern and presents them
  # in an interactive chooser menu. If a file is selected, its content is read
  # and returned. If the user chooses to exit or no file is selected, the
  # method returns nil.
  #
  # @param pattern [ String ] the glob pattern to search for files (defaults to '**/*')
  #
  # @return [ String, nil ] the content of the selected file or nil if no file
  #   was chosen
  def input(pattern)
    pattern ||= '**/*'
    if filename = choose_filename(pattern)
      File.read(filename)
    end
  end

  # The choose_filename method selects a file from a list of matching files.
  #
  # This method searches for files matching the given glob pattern, presents
  # them in an interactive chooser menu, and returns the selected filename. If
  # the user chooses to exit or no file is selected, the method returns nil.
  #
  # @param pattern [ String ] the glob pattern to search for files (defaults to '**/*')
  #
  # @return [ String, nil ] the path to the selected file or nil if no file was chosen
  def choose_filename(pattern)
    files = Dir.glob(pattern).select { File.file?(_1) }
    files.unshift('[EXIT]')
    case chosen = OllamaChat::Utils::Chooser.choose(files)
    when '[EXIT]', nil
      STDOUT.puts "Exiting chooser."
      return
    else
      chosen
    end
  end

  # The context_spook method collects and returns project context using the
  # context_spook library.
  #
  # This method generates structured project context that can be used to
  # provide AI models with comprehensive information about the codebase. It
  # supports both:
  # - On-the-fly pattern matching for specific file patterns
  # - Loading context from predefined definition files in ./.contexts/
  #
  # When patterns are provided, it collects files matching the glob patterns
  # and generates context data including file contents, sizes, and metadata.
  # When no patterns are provided, it loads the default context definition
  # file.
  #
  # @param patterns [Array<String>, nil] Optional array of glob patterns to
  #   filter files
  # @return [String, nil] JSON string of context data or nil if no context
  #   could be generated
  #
  # @example Collect context for Ruby files only
  #   context_spook(['lib/**/*.rb'])
  #
  # @example Collect context for multiple patterns
  #   context_spook(['lib/**/*.rb', 'spec/**/*.rb'])
  #
  # @example Load default context
  #   context_spook(nil)
  def context_spook(patterns)
    if patterns
      ContextSpook::generate_context(verbose: true) do |context|
        context do
          Dir.glob(patterns).each do |filename|
            File.file?(filename) or next
            file filename
          end
        end
      end.to_json
    else
      if context_filename = choose_filename('.contexts/*.rb')
        ContextSpook.generate_context(context_filename, verbose: true).to_json
      end
    end
  end

  # The compose method opens an editor to compose content.
  #
  # This method checks for a configured editor and opens a temporary file in
  # that editor for the user to compose content. Upon successful editing, it
  # reads the content from the temporary file and returns it. If the editor
  # fails or no editor is configured, appropriate error messages are displayed
  # and nil is returned.
  #
  # @return [ String, nil ] the composed content if successful, nil otherwise
  def compose
    unless editor = OllamaChat::EnvConfig::EDITOR?
      STDERR.puts "Editor required for compose, set env var "\
        "#{OllamaChat::EnvConfig::EDITOR!.env_var.inspect}."
      return
    end
    Tempfile.open do |tmp|
      result = system %{#{editor} #{tmp.path.inspect}}
      if result
        return File.read(tmp.path)
      else
        STDERR.puts "Editor failed to edit #{tmp.path.inspect}."
      end
    end
    nil
  end
end
