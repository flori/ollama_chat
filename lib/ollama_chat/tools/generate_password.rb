# A tool for generating secure random passwords.
#
# This tool now accepts either a `length` (default: 16) **or** a `bits`
# requirement.  If `bits` is supplied, the password length is derived
# automatically from the chosen alphabet – the same logic that
# `Tins::Token` uses internally.
#
# The tool integrates with the Ollama tool‑calling system and
# produces a JSON payload containing the password, the effective
# length, the bits used, and the alphabet type.
class OllamaChat::Tools::GeneratePassword
  include OllamaChat::Tools::Concern

  # Registration helper
  def self.register_name = 'generate_password'

  # Creates and returns a tool definition for password generation.
  #
  # The function signature now includes an optional `bits` integer
  # parameter that is mutually exclusive with `length`.
  def tool
    description = <<~EOT
      Generate a cryptographically secure random password with configurable parameters.

      **Required Parameters (mutually exclusive):**
      - `length` (integer): Specify the exact password length in characters
      - `bits` (integer): Specify the minimum bits of entropy required
                          (password length is calculated automatically based on
                          the chosen alphabet type)

      **Alphabet Type (required for all password generation):**
      - `alphabet_type` (string): Choose the character set for generation:
        - `"default"`: Combined alphabet with letters, numbers, and symbols
        - `"base64"`: Base64 alphabet (52 characters: A-Z, a-z, 0-9, +, /)
        - `"base32"`: Base32 alphabet (32 characters)
          - Per default the alphabet from RFC 4648 is used ABCDEFGHIJKLMNOPQRSTUVWXYZ234567
          - If extended flag is true,
              - 0123456789ABCDEFGHIJKLMNOPQRSTUV is used for uppercase true, or
              - 0123456789abcdefghijklmnopqrstuv is used for uppercase false.
        - `"base16"`: Base16 (hexadecimal) alphabet (16 characters: 0-9, A-F or a-f)

      **Optional Character Set Flags (only apply when alphabet_type is "default"):**
      - `letters` (boolean): Include alphabetic characters (default: true)
      - `numbers` (boolean): Include numeric characters (default: true)
      - `symbols` (boolean): Include special characters (default: false)

      **Case Sensitivity (only applies when alphabet_type is "base16" or "base32" with extended hex):**
      - `uppercase` (boolean): Use uppercase letters, otherwise use lowercase letters (default: false)

      **Usage Examples:**
      - Generate a default password: `{ "length": 16 }`
      - Generate a 128-bit password: `{ "bits": 128 }`
      - Generate a base32 password: `{ "alphabet_type": "base32" }`
      - Generate an uppercase base16 password: `{ "alphabet_type": "base16", "uppercase": true }`
      - Generate a base32 password with extended characters: `{ "alphabet_type": "base32", "extended": true }`
      - Generate a password with symbols: `{ "symbols": true }`
      EOT
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description:,
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            length: Tool::Function::Parameters::Property.new(
              type: 'integer',
              description: 'The length of the password (mutually exclusive with bits)'
            ),
            bits: Tool::Function::Parameters::Property.new(
              type: 'integer',
              description: 'The minimum number of bits of entropy (mutually exclusive with length)'
            ),
            letters: Tool::Function::Parameters::Property.new(
              type: 'boolean',
              description: 'Include letters (default: true)'
            ),
            numbers: Tool::Function::Parameters::Property.new(
              type: 'boolean',
              description: 'Include numbers (default: true)'
            ),
            symbols: Tool::Function::Parameters::Property.new(
              type: 'boolean',
              description: 'Include symbols (default: false)'
            ),
            alphabet_type: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'Type of alphabet: "default", "base64", "base32", "base16" (default: "default")'
            ),
            uppercase: Tool::Function::Parameters::Property.new(
              type: 'boolean',
              description: 'Uppercase symbols (default: false)'
            ),
            extended: Tool::Function::Parameters::Property.new(
              type: 'boolean',
              description: 'Extended base32 (default: false)'
            ),
          },
          required: []
        )
      )
    )
  end

  # Executes the password generation operation.
  #
  # @param tool_call [Ollama::Tool::Call] the tool call object containing function details
  # @param opts [Hash] additional options
  # @option opts [ComplexConfig::Settings] :config the configuration object
  # @return [String] the generated password as a JSON string
  def execute(tool_call, **opts)
    config = opts[:config]
    args = tool_call.function.arguments

    # Parse and validate parameters
    length        = args.length
    bits          = args.bits
    letters       = args.letters.nil? ? true : args.letters
    numbers       = args.numbers.nil? ? true : args.numbers
    symbols       = args.symbols.nil? ? false : args.symbols
    uppercase     = args.uppercase.nil? ? false : args.uppercase
    extended      = args.extended.nil? ? false : args.extended
    alphabet_type = args.alphabet_type || 'default'

    length.nil? ^ bits.nil? or
      raise ArgumentError, 'require either bits or length of password'

    # Build the alphabet
    alphabet = build_alphabet(
      letters:, numbers:, symbols:, uppercase:, extended:, type: alphabet_type
    )

    # Generate the password using Tins::Token
    token = if bits
              Tins::Token.new(bits:, alphabet:)
            else
              Tins::Token.new(length:, alphabet:)
            end

    result = {
      password:      token,
      length:        token.length,
      bits:          token.bits,
      alphabet_type: alphabet_type,
      uppercase:     ,
      extended:      ,
      generated_at:  Time.now.iso8601
    }
    if alphabet_type == 'default'
      result |= {
        letters:,
        numbers:,
        symbols:,
      }
    end
    result.to_json
  rescue => e
    {
      error: e.class,
      message: e.message,
    }.to_json
  end

  private

  # Builds a custom alphabet based on character set preferences.
  #
  # @param letters [Boolean] whether to include letters
  # @param numbers [Boolean] whether to include numbers
  # @param symbols [Boolean] whether to include symbols
  # @param type [String] the type of alphabet to use
  # @return [String] the constructed alphabet string
  def build_alphabet(letters:, numbers:, symbols:, uppercase:, extended:, type:)
    case type
    when 'base64'
      Tins::Token::BASE64_ALPHABET
    when 'base32'
      if extended
        if uppercase
          Tins::Token::BASE32_EXTENDED_UPPERCASE_HEX_ALPHABET
        else
          Tins::Token::BASE32_EXTENDED_LOWERCASE_HEX_ALPHABET
        end
      else
        Tins::Token::BASE32_ALPHABET
      end
    when 'base16'
      if uppercase
        Tins::Token::BASE16_UPPERCASE_ALPHABET
      else
        Tins::Token::BASE16_LOWERCASE_ALPHABET
      end
    else
      alphabet_parts = []

      if letters
        # First 52 chars (letters)
        alphabet_parts << Tins::Token::DEFAULT_ALPHABET.slice(0, 52)
      end

      if numbers
        # Next 10 chars (numbers)
        alphabet_parts << Tins::Token::DEFAULT_ALPHABET.slice(52, 10)
      end

      if symbols
        alphabet_parts << "!@#$%^&*()_+-=[]{}|;:,.<>?"
      end

      alphabet_parts.join
    end
  end

  self
end.register
