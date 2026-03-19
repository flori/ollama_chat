# Utility for completing file system paths in the interactive shell.
#
# The class is instantiated with the text that precedes the current
# completion request (`pre`) and the raw input string (`input`).
#
# It supports two common patterns used by the CLI:
#   * ``./foo`` – relative paths starting with a dot
#   * ``~/foo`` – home‑directory expansion
#
# The public API is a single method:
#   * `#complete` – returns an array of matching paths that start with
#     the user’s current input.
#
# The implementation is deliberately lightweight and does not depend on
# external libraries.  It uses `Dir.glob` to gather candidates and then
# filters them with `String#start_with?`.
#
# Example
# -------
#   completer = OllamaChat::Utils::PathCompleter.new("cd ", "./app")
#   completions = completer.complete
#   # => ["./app/models", "./app/controllers", ...]
#
# The class is intentionally simple so that it can be reused by
# different parts of the chat application.
class OllamaChat::Utils::PathCompleter
  # @param pre [String] the text that precedes the completion request
  # @param input [String] the current input that the user has typed
  def initialize(pre, input)
    @pre, @input = pre, input
  end

  # Return an array of path completions that match the current input.
  #
  # @return [Array<String>]
  def complete
    before = [@pre, @input].join
    before =~ %r(([.~])\/\S*)
    path, first = $&, $1
    case first
    when ?. # relative path starting with .
      dir = File.join(File.directory?(path) ? path : File.dirname(path), '')
      Dir.glob(dir + ?*).select { |f| f.start_with?(@input) }
    when ?~
      path_expanded = expand_path(path)
      dir = File.join(File.directory?(path_expanded) ? path_expanded : File.dirname(path_expanded), '')
      Dir.glob(dir + ?*).select { |f| f.start_with?(expand_path(@input)) }
        .map { |f| f.sub(expand_path(?~), ?~) }
    else
      []
    end
  end

  # Expands a given filesystem path to an absolute path, resolving any relative
  # components and symlinks
  #
  # @param path [String] the path to expand
  # @return [String] the absolute path
  def expand_path(path)
    File.expand_path(path)
  end
end
