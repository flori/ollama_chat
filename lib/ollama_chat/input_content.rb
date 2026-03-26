require 'tempfile'

# A module that provides input content processing functionality for OllamaChat.
#
# The InputContent module encapsulates methods for reading and returning
# content from selected files, selecting files from a list of matching files,
# and collecting project context using the context_spook library. It supports
# interactive file selection and context collection for enhancing chat
# interactions with local or remote content.
module OllamaChat::InputContent
  # The file_set_each method iterates over a set of files matched by the given
  # patterns, optionally including all files, and yields each file to the
  # supplied block.
  # It returns the array of files that were processed.
  #
  # @param patterns [Array<String>] the list of patterns to match files against
  # @param all [TrueClass, FalseClass] whether to include all files in the set
  # @yield [file] yields each file to the supplied block
  # @return [Array<File>] the array of files that were processed
  def file_set_each(patterns, all: false, &block)
    files = all ? all_file_set(patterns) : choose_file_set(patterns)
    block and files.each(&block)
    files
  end

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
    files = choose_file_set(patterns)
    files.each_with_object('') do |filename, result|
      result << ("%s:\n\n%s\n\n" % [ filename, filename.read ])
    end.full?
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
  def context_spook(patterns, all: false)
    format = config.context.format
    myself = self
    if patterns
      ContextSpook::generate_context(verbose: true, format:) do |context|
        context do
          myself.file_set_each(patterns, all:) do |filename|
            filename.file? or next
            file filename.to_path
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

  # The all_file_set method aggregates files matching the provided glob
  # patterns into a set.
  #
  # @param patterns [Array<String>] an array of glob patterns to match files
  #   against
  #
  # @return [Set<Pathname>] a set containing all Pathname objects that match
  #   any of the given patterns
  def all_file_set(patterns)
    files = Set[]
    patterns.each do |pattern|
      files.merge(Pathname.glob(pattern))
    end
    files.map(&:expand_path)
  end

  # The provide_file_set_content method collects content from a set of files
  # that match the supplied patterns, optionally processing all files or
  # allowing the caller to choose a subset interactively. It concatenates each
  # file's name with the content returned by the provided block, separating
  # each entry with newlines, resulting in a single string containing the
  # processed content for all selected files.
  #
  # @param patterns [Array<String>] # the glob patterns used to find files
  # @param all [TrueClass, FalseClass] whether to process all matching files or
  #   let the caller choose a subset
  #
  # @yield [filename] the block that processes each filename
  # @return [String] the concatenated result of the block applied to each file
  def provide_file_set_content(patterns, all: false, &block)
    total = 0
    all and file_set_each(patterns, all:) { total += 1 }
    count = 0
    file_set_each(patterns, all:).each_with_object('') do |filename, result|
      count += 1
      if all
        STDOUT.puts "Handling File (#{bold{count}}/#{bold{total}}):"
      else
        STDOUT.puts "Handling File (#{bold{count}}):"
      end
      result << ("%s:\n\n%s\n\n" % [ filename, block.(filename) ])
    end.full?
  end
end
