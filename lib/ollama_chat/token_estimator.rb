# Provides tools for estimating token counts across different models and contexts.
module OllamaChat::TokenEstimator
end

# Requires the core estimation implementations.
require 'ollama_chat/token_estimator/crude'

# A data structure that holds the results of a token estimation,
# providing convenient formatting methods for both byte size and token count.
module OllamaChat::TokenEstimator
  # Represents the result of a calculation including raw values
  # and their human-readable formatted strings.
  class Estimate < Struct.new(:bytes, :tokens)
    include OllamaChat::Utils::ValueFormatter

    # Returns the byte count in a formatted string (e.g., "1.2 KB").
    # @return [String] The formatted byte size.
    def tokens_formatted
      format_tokens(tokens)
    end

    # Returns the byte count as a formatted string.
    # @return [String] The formatted byte size.
    def bytes_formatted
      format_bytes(bytes)
    end
  end

  # Estimates token count for a given piece of content.
  #
  # @param text [String, Integer] The content to estimate (string or raw byte count).
  # @return [OllamaChat::TokenEstimator::Estimate] An object containing the results.
  def self.estimate(text)
    OllamaChat::TokenEstimator::Crude.new(text).perform
  end
end
