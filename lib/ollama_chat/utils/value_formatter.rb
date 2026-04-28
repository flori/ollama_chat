# Module to format values for user consumption.
module OllamaChat::Utils::ValueFormatter
  # Formats a byte value into a human‑readable string with units
  #
  # @param bytes [Integer] the number of bytes to format
  # @return [String] the formatted byte string
  def format_bytes(bytes)
    Tins::Unit.format(bytes, unit: ?B, prefix: :iec_uc, format: '%.1f %U')
  end

  # Formats a token count into a human‑readable string with units
  #
  # @param tokens [Integer] the number of tokens to format
  # @return [String] the formatted token string
  def format_tokens(tokens)
    Tins::Unit.format(tokens, unit: ?T, prefix: :si_uc, format: '%.1f %U')
  end
end
