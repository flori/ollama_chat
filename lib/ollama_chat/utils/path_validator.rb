# Utility module that centralises path‑validation logic for OllamaChat tools.
#
# The module is deliberately kept **private** – it is mixed into tool classes
# that need to validate file paths against a whitelist.  By extracting the
# logic into a reusable mixin we avoid duplication and make the intent of
# each tool explicit.
#
# @private
module OllamaChat::Utils::PathValidator
  # Validates that a supplied path is located inside one of the allowed
  # directories.
  #
  # The method performs the following steps:
  #
  # 1. Canonicalises the supplied *path* using `Pathname#expand_path` and
  #    `cleanpath(true)` – this resolves symlinks and removes `..` components.
  # 2. Normalises each entry in *allowed* into an absolute, cleaned `Pathname`
  #    (an empty or `nil` *allowed* list results in an empty array, which
  #    causes every path to be rejected – the safest default).
  # 3. Checks that the canonicalised *path* starts with any of the allowed
  #    directories.
  # 4. If the check fails, raises an `OllamaChat::InvalidPathError` that
  #    carries the offending path for debugging and error reporting.
  #
  # @param path [String, Pathname] The file or directory path to validate.
  # @param allowed [String, Array<String>, nil] A list of directory paths
  #   that are considered safe.  Each entry is expanded to an absolute
  #   `Pathname`.  Passing `nil` or an empty array will reject all paths.
  # @return [Pathname] The canonicalised absolute path if validation passes.
  # @raise [OllamaChat::InvalidPathError] when *path* is not inside any
  #   of the allowed directories.
  # @private
  def assert_valid_path(path, allowed)
    target_path = Pathname.new(path).expand_path.cleanpath(true)

    allowed_dirs = Array(allowed).map do |p|
      Pathname.new(p).expand_path.cleanpath
    end

    valid_path = allowed_dirs.any? do |allowed_dir|
      target_path.to_s.start_with?(allowed_dir.to_s)
    end

    unless valid_path
      error = OllamaChat::InvalidPathError.new(
        "Path #{path} is not within allowed directories: " \
        "#{allowed_dirs&.join(', ') || '∅'}"
      )
      error.path = path
      raise error
    end

    target_path
  end
end
