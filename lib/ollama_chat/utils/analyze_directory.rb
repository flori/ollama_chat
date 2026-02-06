# A module that provides functionality for analyzing directory structures and
# generating file listings.
#
# The AnalyzeDirectory module offers methods to traverse directory hierarchies
# and create structured representations of file systems. It supports recursive
# directory traversal, filtering of hidden files and symbolic links, and
# generation of detailed file and directory information including paths, names,
# and metadata.
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
  def generate_structure(path = ?., exclude: [])
    exclude = Array(exclude).map { Pathname.new(it).expand_path }
    path    = Pathname.new(path).expand_path
    entries = []
    path.children.sort.each do |child|
      # Skip hidden files/directories
      next if child.basename.to_s.start_with?('.')
      # Skip symlinks
      next if child.symlink?
      # Skip if excluded
      next if exclude.any? { child.fnmatch?(it.to_s, File::FNM_PATHNAME) }

      if child.directory?
        entries << {
          type: 'directory',
          name: child.basename.to_s,
          path: child.expand_path.to_s,
          children: generate_structure(child)
        }
      elsif child.file?
        entries << {
          type: 'file',
          path: child.expand_path.to_s,
          name: child.basename.to_s
        }
      end
    end
    entries
  rescue => e
    { error: e.class, message: e.message }
  end
end
