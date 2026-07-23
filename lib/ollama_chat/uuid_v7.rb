require 'securerandom'

# Provides functionality to generate UUID version 7 (time-ordered) identifiers.
# This module ensures compatibility across different Ruby versions by using
# native `SecureRandom.uuid_v7` when available, and providing a custom
# implementation for older versions (e.g., Ruby < 3.3).
module OllamaChat::UUIDV7
  if SecureRandom.respond_to?(:uuid_v7)
    # Generates a UUID version 7 identifier according to RFC 9562.
    #
    # @return [String] A time-ordered UUID v7 string.
    def self.generate
      SecureRandom.uuid_v7
    end
  else
    # Generates a UUID version 7 identifier according to RFC 9562.
    # This custom implementation is used for Ruby versions where
    # `SecureRandom.uuid_v7` is not natively available.
    #
    # @return [String] A time-ordered UUID v7 string.
    def self.generate
      ms   = Process.clock_gettime(Process::CLOCK_REALTIME, :millisecond)
      rand = SecureRandom.random_bytes(10)
      rand.setbyte(0, rand.getbyte(0) & 0x0f | 0x70) # version
      rand.setbyte(2, rand.getbyte(2) & 0x3f | 0x80) # variant
      "%08x-%04x-%s" % [
        (ms & 0x0000_ffff_ffff_0000) >> 16,
        (ms & 0x0000_0000_0000_ffff),
        rand.unpack("H4H4H12").join("-")
      ]
    end
  end
end
