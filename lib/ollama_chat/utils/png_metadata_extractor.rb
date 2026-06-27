require 'base64'

# Extracts embedded metadata from PNG image files, such as character profiles,
# ComfyUI workflows, and prompts stored in 'tEXt' chunks.
module OllamaChat::Utils::PNGMetadataExtractor
  include OllamaChat::Utils::UTF8Converter
  extend OllamaChat::Utils::UTF8Converter

  module_function

  # Extracts all 'tEXt' chunk metadata from the provided IO object.
  #
  # @param io [IO] An IO-like object providing access to the PNG binary data.
  # @return [Hash, nil] A hash of { keyword => text } if a valid PNG is found,
  #   otherwise nil.
  def extract_all(io)
    data = if io.respond_to?(:binmode)
             io.binmode
             io.read
           elsif io.respond_to?(:binread)
             io.binread
           else
             return nil
           end

    # PNG Signature is 8 bytes: \x89PNG\r\n\x1a\n
    pos = 8
    metadata = {}

    while pos < data.length
      # 1. Read Length (4 bytes, Big Endian)
      length = data[pos, 4]&.unpack1('L>')
      break unless length

      pos += 4

      # 2. Read Chunk Type (4 bytes)
      type = data[pos, 4]
      pos += 4

      # 3. Read Chunk Data
      chunk_data = data[pos, length]
      pos += length

      # 4. Skip CRC (4 bytes)
      pos += 4

      if type == 'tEXt'
        # tEXt chunks are formatted as: Keyword + NULL Byte + Text
        keyword, text = chunk_data.split("\x00", 2)
        metadata[keyword] = text if keyword
      end
    end

    metadata.empty? ? nil : metadata
  ensure
    io.ask_and_send(:rewind)
  end

  # Decodes a Base64 encoded character profile and validates it as JSON.
  #
  # @param text [String] The raw 'chara' metadata value.
  # @return [String, nil] The decoded JSON string if valid, otherwise nil.
  def decode_character(text)
    return nil unless text

    begin
      decoded = Base64.decode64(text)
      decoded = convert_to_utf8(decoded)
      JSON.parse(decoded) # Validation check
      decoded
    rescue JSON::ParserError, ArgumentError
      nil
    end
  end

  # Convenience method to extract a character profile from a PNG.
  # Maintained for backward compatibility with existing call sites.
  #
  # @param io [IO] An IO-like object providing access to the PNG binary data.
  # @return [String, nil] The decoded JSON string if found and valid, otherwise nil.
  def extract_character(io)
    metadata = extract_all(io) or return
    decode_character(metadata['chara'])
  end

  # Extracts the prompt metadata from a PNG image.
  #
  # @param io [IO] An IO-like object providing access to the PNG binary data.
  # @return [String, nil] The raw prompt text if found, otherwise nil.
  def extract_prompt(io)
    metadata = extract_all(io) or return
    convert_to_utf8(metadata['prompt'])
  end

  # Extracts the workflow metadata from a PNG image (e.g., ComfyUI).
  #
  # @param io [IO] An IO-like object providing access to the PNG binary data.
  # @return [String, nil] The raw workflow JSON string if found, otherwise nil.
  def extract_workflow(io)
    metadata = extract_all(io) or return
    convert_to_utf8(metadata['workflow'])
  end
end
