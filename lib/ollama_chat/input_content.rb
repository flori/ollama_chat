require 'tempfile'

# A module that provides input content processing functionality for OllamaChat.
#
# The InputContent module encapsulates methods for reading and returning
# content from selected files, selecting files from a list of matching files,
# and collecting project context using the context_spook library. It supports
# interactive file selection and context collection for enhancing chat
# interactions with local or remote content.
module OllamaChat::InputContent
  private

  # The input method selects and reads content from files matching a pattern.
  #
  # This method prompts the user to select files matching the given glob
  # pattern, reads their content, and returns a concatenated string with each
  # file's content preceded by its filename.
  #
  # @param patterns [Array<String>] the glob patterns to search for files (defaults to '**/*')
  #
  # @return [String] a concatenated string of file contents with filenames as headers
  def input(patterns)
    patterns ||= '**/*'
    patterns = Array(patterns)
    files = Set[]
    while filename = choose_filename(patterns, chosen: files)
      files << filename.expand_path
    end
    result = ''
    files.each do |filename|
      result << ("%s:\n\n%s\n\n" % [ filename, filename.read ])
    end
    result.full?
  end

  # The choose_filename method selects a file from a list of matching files. It
  # searches for files matching the given pattern, excludes already chosen
  # files, and presents them in an interactive chooser menu.
  #
  # @param patterns [ Array<String> ] the glob patterns to search for files
  # @param chosen [ Set ] a set of already chosen filenames to exclude from
  #   selection
  #
  # @return [ Pathname, nil ] the selected filename or nil if no file was chosen or user exited
  def choose_filename(patterns, chosen: nil)
    patterns = Array(patterns)
    files = patterns.flat_map { Pathname.glob(_1) }
    files = files.reject { chosen&.member?(_1.expand_path) }.select { _1.file? }
    files.unshift('[EXIT]')
    case chosen_file = OllamaChat::Utils::Chooser.choose(files)
    when '[EXIT]', nil
      STDOUT.puts "Exiting chooser."
      return
    else
      Pathname.new(chosen_file)
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
    format = config.context.format
    if patterns
      ContextSpook::generate_context(verbose: true, format:) do |context|
        context do
          Dir.glob(patterns).each do |filename|
            File.file?(filename) or next
            file filename
          end
        end
      end.to_json
    else
      if context_filename = choose_filename('.contexts/*.rb')
        ContextSpook.generate_context(context_filename, verbose: true, format:).
          send("to_#{format.downcase}")
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
    Tempfile.open do |tmp|
      if result = edit_file(tmp.path)
        return File.read(tmp.path)
      else
        STDERR.puts "Editor failed to edit #{tmp.path.inspect}."
      end
    end
    nil
  end
end
