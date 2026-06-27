# A utility module for converting strings to UTF-8 encoding. This module
# provides methods to ensure text is properly encoded as UTF-8, replacing
# invalid or undefined characters to prevent encoding errors.
module OllamaChat::Utils::UTF8Converter
  # Converts the given text to UTF-8 encoding, replacing invalid or undefined
  # characters.
  #
  # @param text [String, nil] the text to be converted if any
  # @return [String, nil] the UTF-8 encoded string or nil
  def convert_to_utf8(text)
    text&.encode('UTF-8', invalid: :replace, undef: :replace)
  end
end
