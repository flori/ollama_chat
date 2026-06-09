# Provides a "best-effort" estimation of token counts based on the
# character count or byte size of the input content.
class OllamaChat::TokenEstimator::Crude
  # Initializes a new crude estimator with the provided source.
  #
  # @param arg [String, Integer] The content to estimate (string or raw byte count).
  # @raise [ArgumentError] if the input is not a string or an integer.
  def initialize(arg)
    if text = arg.ask_and_send(:to_str)
      @bytes = text.size
    elsif bytes = arg.ask_and_send(:to_int)
      @bytes = bytes
    else
      raise ArgumentError, "#{arg.inspect} cannot be used to estimate"
    end
  end

  # Performs the estimation calculation and returns an Estimate object.
  #
  # @return [OllamaChat::TokenEstimator::Estimate]
  def perform
    tokens = (@bytes.to_f / 3.5).ceil
    OllamaChat::TokenEstimator::Estimate.new(bytes: @bytes, tokens:)
  end
end
