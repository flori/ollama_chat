require 'file/tail'

# Truncates a log file in-place, keeping only the last N lines.
#
# Uses `File::Tail#backward` to seek to the start of the tail portion
# without loading the entire file into memory. The file is rewritten
# in-place (same inode) so that tailing processes (e.g.
# `ollama_chat_log`) can continue following the file.
module OllamaChat::Utils::LogRotation
  # Truncates a log file in-place, keeping only the last +keep_lines+.
  #
  # If the file has fewer lines than +keep_lines+, it is left untouched.
  # The operation is a no-op if the file does not exist.
  #
  # @param path [String, Pathname] the log file to truncate
  # @param keep_lines [Integer] the number of lines to retain
  def self.truncate_tail(path, keep_lines:)
    return unless File.exist?(path)
    File.open(path, 'r+') do |f|
      f.extend(File::Tail)
      f.backward(keep_lines)
      return if f.pos.zero?
      tail = f.read
      f.rewind
      f.write(tail)
      f.truncate(f.pos)
    end
  end
end
