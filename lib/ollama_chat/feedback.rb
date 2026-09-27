# Provides typed user-facing output to STDOUT.
#
# @example
#   feedback("Done.", type: :success)     # → ✅ Done.
#   feedback("Cancelled.", type: :cancel) # → ❌ Cancelled.
module OllamaChat::Feedback
  # Glyph prefixes keyed by message type.
  #
  # Unknown types trigger a `warn` via the default proc
  # but still emit the message without a prefix.
  PREFIXES = Hash.new {
    warn "type %s not defined!" % _2.inspect unless _2.nil?
  }.merge(
    success: "\u2705",        # ✅
    cancel:  "\u274C",        # ❌
    denied:  "\u{1F6AB}",     # 🚫
    warn:    "\u26A0",        # ⚠️
    info:    "\u2139",        # ℹ️
    alarm:   "\u{1F514}"      # 🔔
  )
  private_constant :PREFIXES

  # Write a user-facing message to STDOUT with an optional
  # glyph prefix.
  #
  # @param msg [String] The message body.
  # @param type [Symbol, nil] Selects the prefix from
  #   {PREFIXES}. Omit for unadorned output.
  # @param output [IO] The IO to write to. Defaults to
  #   {STDOUT}. Override when routing to a different stream
  #   (e.g., a `use_pager` yielded IO).
  # @param newline [Boolean] When true (default), ensures the
  #   message ends with exactly one newline before writing.
  #   Set to false for mid-line or no-trailing-newline output.
  # @return [nil]
  def feedback(msg, type: nil, output: STDOUT, newline: true)
    prefix = PREFIXES[type&.to_sym]&.+(' ')
    newline and msg = msg.sub(/(?<!\n)\z/, ?\n)
    output.print(prefix.to_s + msg)
  end
end
