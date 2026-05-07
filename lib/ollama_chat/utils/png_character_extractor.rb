# frozen_string_literal: true

# Extracts embedded character profiles from PNG image files.
#
# This module specifically looks for 'tEXt' chunks within a PNG file that contain
# a 'chara' keyword, which is expected to hold a Base64 encoded JSON string.
module OllamaChat::Utils::PNGCharacterExtractor
  module_function

  # Extracts the character profile JSON from the provided IO object.
  #
  # @param io [IO] An IO-like object providing access to the PNG binary data.
  # @return [String, nil] The decoded JSON string if a valid 'chara' profile is found,
  #   otherwise nil.
  def extract_character_json(io)
    data = if io.respond_to?(:binmode)
             io.binmode
             io.read
           elsif io.respond_to?(:binread)
             io.binread
           else
             return nil
           end

    # PNG Signature is 8 bytes: \x89PNG\r\n\x1a\n
    # We start reading chunks after the signature
    pos = 8

    while pos < data.length
      # 1. Read Length (4 bytes, Big Endian)
      length = data[pos, 4].unpack1('L>')
      pos += 4

      # 2. Read Chunk Type (4 bytes)
      type = data[pos, 4]
      pos += 4

      # 3. Read Chunk Data
      chunk_data = data[pos, length]
      pos += length

      # 4. Skip CRC (4 bytes)
      pos += 4

      # We are only interested in 'tEXt' chunks
      if type == 'tEXt'
        # tEXt chunks are formatted as: Keyword + NULL Byte + Text
        # We split only on the first NULL byte
        keyword, text = chunk_data.split("\x00", 2)

        if keyword == 'chara'
          begin
            # The content is Base64 encoded UTF-8 JSON
            decoded_json = Base64.decode64(text)
            JSON.parse(decoded_json)
            return decoded_json
          rescue JSON::ParserError, ArgumentError
            return nil
          end
        end
      end
    end
  end
end
