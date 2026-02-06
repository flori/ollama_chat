module OllamaChat::Utils::AnalyzeDirectory
  module_function

  # Generates a directory structure representation with files and
  # subdirectories.
  #
  # @param path [String] the path to start generating the structure from,
  # defaults to current directory
  #
  # @return [Array<Hash>, Hash] an array of hashes representing files and
  # directories, or a hash with error information if an exception occurs
  # @return [Array] an empty array if the path is invalid or has no children
  # @return [Hash] a hash with error details if an exception is raised during processing
  #
  # @example Generate structure for current directory
  #   generate_structure
  #
  # @example Generate structure for a specific path
  #   generate_structure('/path/to/directory')
  #
  # @note Hidden files and directories (starting with '.') are skipped
  # @note Symbolic links are skipped
  # @note The method uses recursive calls to traverse subdirectories
  # @note If an error occurs during traversal, it returns a hash with error details
  def generate_structure(path = ?.)
    path = Pathname.new(path).expand_path
    entries = []
    path.children.sort.each do |child|
      # Skip hidden files/directories
      next if child.basename.to_s.start_with?('.')
      # Skip symlinks
      next if child.symlink?

      if child.directory?
        entries << {
          type: 'directory',
          name: child.basename.to_s,
          children: generate_structure(child)
        }
      elsif child.file?
        entries << {
          type: 'file',
          name: child.basename.to_s
        }
      end
    end
    entries
  rescue => e
    { error: e.class, message: e.message }
  end
end
