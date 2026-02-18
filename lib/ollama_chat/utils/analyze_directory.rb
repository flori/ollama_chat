require 'pathname'

module OllamaChat
  module Utils
    # The `OllamaChat::Utils::AnalyzeDirectory` module provides a small,
    # dependency‑free helper for walking a directory tree and producing a
    # nested hash representation of the file system.
    #
    # It supports:
    #
    # * Recursive traversal of directories
    # * Skipping hidden files/directories and symbolic links
    # * Excluding arbitrary paths via glob patterns
    # * Limiting the depth of the returned tree
    #
    # Example
    #
    #   require_relative 'analyze_directory'
    #
    #   include OllamaChat::Utils::AnalyzeDirectory
    #
    #   structure = generate_structure(
    #     '/path/to/dir',
    #     exclude: ['tmp', 'vendor'],
    #     max_depth: 3
    #   )
    #
    #   puts structure.inspect
    #
    # @api public
    module AnalyzeDirectory
      # Generate a nested hash representation of a directory tree.
      #
      # @param path [String, Pathname] The root directory to walk.
      #   Defaults to the current working directory (`"."`).
      # @param exclude [Array<String, Pathname>] Glob patterns (relative to
      #   +path+) that should be ignored during traversal.
      # @param max_depth [Integer, nil] Optional depth limit. If `nil`,
      #   the entire tree is returned.  When an integer is supplied, all
      #   entries deeper than that depth are pruned.
      #
      # @return [Array<Hash>] An array of entry hashes.  Each hash contains:
      #   * `:type`   – "file" or "directory"
      #   * `:name`   – Base name of the file/directory
      #   * `:path`   – Absolute path
      #   * `:depth`  – Depth relative to the root (root = 0)
      #   * `:height` – The maximum depth found in the entire tree
      #   * `:children` – Array of child entry hashes (only for directories)
      #
      # @raise [StandardError] Any exception raised during traversal is
      #   rescued and returned as a hash with `:error` and `:message`
      #   keys.
      #
      # @example Basic usage
      #   generate_structure(
      #     '/tmp',
      #     exclude: ['cache', 'logs'],
      #     max_depth: 2
      #   )
      #
      # @api public
      def generate_structure(path = '.', exclude: [], max_depth: nil)
        entries = recurse_generate_structure(path, exclude:)
        height  = 0

        structure_each_entry(entries) do |e|
          height = e[:depth] if e[:depth] > height
        end

        structure_each_entry(entries) { |e| e[:height] = height }

        if max_depth && max_depth < height
          structure_each_entry(entries) do |e|
            e[:children]&.reject! { |c| c[:depth] > max_depth }
          end
        end

        entries
      rescue => e
        { error: e.class, message: e.message }
      end

      private

      # Recursively walk *path* and build the tree.
      #
      # @param path [String, Pathname] Directory to traverse.
      # @param exclude [Array<Pathname>] List of absolute paths to skip.
      # @param depth [Integer] Current depth (root = 0).
      #
      # @return [Array<Hash>] Array of entry hashes.
      #
      # @api private
      def recurse_generate_structure(path = '.', exclude: [], depth: 0)
        exclude = Array(exclude).map { |p| Pathname.new(p).expand_path }
        path     = Pathname.new(path).expand_path
        entries  = []

        path.children.sort.each do |child|
          # Skip hidden files/directories
          next if child.basename.to_s.start_with?('.')
          # Skip symlinks
          next if child.symlink?
          # Skip user‑excluded paths
          next if exclude.any? { |e| child.fnmatch?(e.to_s, File::FNM_PATHNAME) }

          if child.directory?
            entries << {
              type:     'directory',
              name:     child.basename.to_s,
              path:     child.expand_path.to_s,
              children: recurse_generate_structure(child, exclude:, depth: depth + 1),
              depth:
            }
          elsif child.file?
            entries << {
              type:  'file',
              name:  child.basename.to_s,
              path:  child.expand_path.to_s,
              depth:
            }
          end
        end

        entries
      end

      # Iterate over every entry in *entries* (depth‑first).
      #
      # @param entries [Array<Hash>] The root array of entries.
      # @yield [Hash] Yields each entry hash.
      #
      # @return [Array<Hash>] The original +entries+ array.
      #
      # @api private
      def structure_each_entry(entries, &block)
        queue = entries.dup
        while entry = queue.shift
          block.(entry)
          queue.concat(entry[:children]) if entry[:children]
        end
        entries
      end
    end
  end
end
