# Provides crude estimations of token counts for various models.
#
# Since actual tokenization depends on the specific model's BPE/SentencePiece
# vocabulary, these methods provide a "best effort" approximation based
# on average character/byte ratios.
module OllamaChat::Utils::TokenEstimator
  # Estimates tokens based on byte size.
  # Assumes an average of 3.5 bytes per token.
  #
  # @param bytes [Integer] The size of the content in bytes
  # @return [Integer] The estimated number of tokens
  def self.estimate(bytes)
    (bytes.to_f / 3.5).ceil
  end
end
