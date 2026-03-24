# Module to format values for user consumption.
module OllamaChat::Utils::ValueFormatter
  # Formats a byte value into a human‑readable string with units
  #
  # @param bytes [Integer] the number of bytes to format
  # @return [String] the formatted byte string
  def format_bytes(bytes)
    Tins::Unit.format(bytes, unit: ?B, prefix: 1024, format: '%.1f %U')
  end
end
