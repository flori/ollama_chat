# Strips ANSI escape sequences from a string.
#
# Handles both SGR (Select Graphic Rendition) sequences like
# `\e[38;2;255;128;0m` and OSC (Operating System Command) sequences
# like `\e]0;title\a` or `\e]8;;url\e\\`.
#
# @example
#   OllamaChat::Utils::StripANSI.strip_ansi("\e[31mred\e[0m")
#   # => "red"
module OllamaChat::Utils::StripANSI
  module_function

  # Matches SGR sequences (e.g. `\e[31m`) and OSC sequences
  # (e.g. `\e]0;title\a`, `\e]8;;url\e\\`).
  #
  # @return [Regexp] the ANSI escape pattern
  ANSI_RE = /\e\[[0-9;?]*[A-Za-z]|\e\].*?(\e\\|\a)/m

  # Removes all ANSI escape sequences from the given string.
  #
  # @param line [String] the string potentially containing ANSI escapes
  # @return [String] the string with all ANSI escape sequences removed
  def strip_ansi(line)
    line.to_s.encode('UTF-8', invalid: :replace, undef: :replace).gsub(ANSI_RE, '')
  end
end
