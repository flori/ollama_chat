# Utility module that centralises path‑validation logic for OllamaChat tools.
#
# The module is deliberately kept **private** – it is mixed into tool classes
# that need to validate file paths against a whitelist.  By extracting the
# logic into a reusable mixin we avoid duplication and make the intent of
# each tool explicit.
module OllamaChat::Utils::PathValidator
  # Validates that a supplied path is located inside one of the allowed
  # directories.
  #
  # The method performs the following steps:
  #
  # * Canonicalises the supplied `path` using `Pathname#expand_path` and
  #   `cleanpath(true)`.
  # * If the `check` option is provided, resolves the path to its real physical
  #   location using `realpath` to prevent symlink traversal attacks.
  # * Normalises each entry in `allowed` into an absolute, cleaned `Pathname`
  #   (an empty or `nil` allowed list results in an empty array, which causes
  #   every path to be rejected – the safest default).
  # * Checks that the canonicalised `path` starts with any of the allowed directories.
  # * If the check fails, raises an `OllamaChat::InvalidPathError` that carries
  #   the offending path for debugging and error reporting.
  #
  # @param path [String, Pathname] The file or directory path to validate.
  # @param allowed [String, Array<String>, nil] A list of directory paths that
  #   are considered safe. Each entry is expanded to an absolute `Pathname`.
  #   Passing `nil` or an empty array will reject all paths.
  #
  # @option check [Symbol, Boolean, nil] Validation mode:
  #   * `:file` - Verifies that the path exists and is a file.
  #   * `:directory` - Verifies that the path exists and is a directory.
  #   * `true` - Verifies only that the path exists (resolves symlinks).
  #   * `nil` (default) - No existence or type check is performed.
  #
  # @return [Pathname] The canonicalised absolute path if validation passes.
  # @raise [OllamaChat::InvalidPathError] when `path` is not inside any of the
  #   allowed directories or, when `check` is set, when the path does not exist
  #   or is of the wrong type.
  def assert_valid_path(path, allowed, check: nil)
    target_path = Pathname.new(path).expand_path.cleanpath(true)

    target_path.dirname.directory? or
      raise OllamaChat::InvalidPathError,
        "#{target_path.dirname.to_s.inspect} is not a directory"

    if check
      begin
        target_path = target_path.realpath
      rescue Errno::ENOENT
        raise OllamaChat::InvalidPathError,
          "#{target_path.to_s.inspect} does not exist"
      end
      case check
      when :file
        target_path.file? or
          raise OllamaChat::InvalidPathError,
          "#{target_path.to_s.inspect} is not a file"
      when :directory
        target_path.directory? or
          raise OllamaChat::InvalidPathError,
          "#{target_path.to_s.inspect} is not a file"
      end
    end

    allowed_dirs, rest = Array(allowed).map do |p|
      Pathname.new(p).expand_path.cleanpath
    end.partition(&:directory?)

    unless rest.empty?
      warn "Ignoring non-directories: #{rest.map(&:to_path).map(&:inspect) * ', '} in assert_valid_path."
    end

    valid_path = allowed_dirs.any? do |allowed_dir|
      check_path = target_path
      check_path.directory? or check_path = check_path.dirname
      check_path.ascend.any? do |tp|
        tp == allowed_dir
      end
    end

    unless valid_path
      error = OllamaChat::InvalidPathError.new(
        "Path #{path.to_s.inspect} is not within allowed directories: " \
        "#{allowed_dirs&.map { _1.to_s.inspect }&.join(', ') || ?∅ }"
      )
      error.path = path
      raise error
    end

    target_path
  end
end
