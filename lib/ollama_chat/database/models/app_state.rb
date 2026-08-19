require 'digest'

# Represents a key/value pair of persistent application state stored in
# the database.
#
# This model provides a generic, JSON-backed store for small bits of
# runtime state that need to survive across sessions—such as the
# XOR-SHA256 fingerprint of the shipped default prompts used for boot
# drift detection.
class OllamaChat::Database::Models::AppState < Sequel::Model(OllamaChat::DB)
  plugin :timestamps, update_on_create: true
  plugin :serialization, :json, :value
  plugin :validation_helpers

  # Validates the application state entry.
  #
  # Ensures that the `key` is present and unique.
  def validate
    super
    validates_presence :key
    validates_unique :key
  end

  # Retrieves the JSON payload stored under the given key.
  #
  # @param key [String, Symbol] the state key to look up
  # @return [Hash, nil] the deserialized JSON payload, or nil if no
  #   record exists for the key
  def self.get(key)
    where(key: key.to_s).first&.value
  end

  # Creates or updates the JSON payload stored under the given key.
  #
  # @param key [String, Symbol] the state key to write
  # @param value [Hash, nil] the JSON-serializable payload to store
  # @return [OllamaChat::Database::Models::AppState] the saved record
  def self.set(key, value)
    if found = where(key: key.to_s).first
      found.update(value:)
      found
    else
      create(key: key.to_s, value:)
    end
  end

  # Computes per-prompt SHA256 hashes and an XOR fingerprint of all shipped
  # default prompts.
  #
  # At boot, if the stored fingerprint differs from the current one, a detail
  # report (modified / added / removed) is printed to STDERR and the user is
  # prompted to accept the new fingerprint. If declined, the old fingerprint
  # is retained and the notice will reappear on the next boot.
  #
  # This method is invoked automatically by the model seeding loop in
  # `OllamaChat::Database.setup_models`.
  #
  # @param chat [OllamaChat::Chat] the chat instance providing the config
  #   and `confirm?`
  def self.seed(chat)
    stored = get(:prompt_defaults_fingerprint)

    stored_fingerprint = stored&.dig('fingerprint')

    hashes = {}
    chat.config.prompts.to_h.each do |context, prompts|
      prompts.each do |name, content|
        hashes["#{context}/#{name}"] =
          Digest::SHA256.hexdigest(content.to_s)
      end
    end

    fingerprint = hashes.values.reduce(0) do |sum, hex|
      sum ^ hex.to_i(16)
    end.to_s(16)

    return true if fingerprint == stored_fingerprint

    if stored&.dig('hashes')
      old     = stored['hashes']
      added   = hashes.keys - old.keys
      removed = old.keys - hashes.keys
      changed = hashes.select { |k, v| old[k] && old[k] != v }.keys

      STDERR.puts "⚠️  Shipped prompts changed since last boot:"
      changed.each { |k| STDERR.puts "  ~ #{k} (modified)" }
      added.each   { |k| STDERR.puts "  + #{k} (new)" }
      removed.each { |k| STDERR.puts "  - #{k} (removed)" }
    elsif !OllamaChat.test_mode?
      STDERR.puts '⚠️  First run — storing prompt fingerprints.'
      set(:prompt_defaults_fingerprint,
          { fingerprint:, hashes:, computed_at: Time.now.iso8601 })
      return true
    end

    prompt = <<~EOT.chomp << ' '
      Keep local prompts (stop nagging)?
      Consider adopting via /prompt sync or /prompt reset. (y/n) %s
    EOT
    if OllamaChat.test_mode? || chat.confirm?(prompt:, yes: /\Ay/i, timeout: 5)
      set(:prompt_defaults_fingerprint,
          { fingerprint:, hashes:, computed_at: Time.now.iso8601 })
    end

    true
  end

  # @!attribute [v] id
  #   @return [Integer] The primary key for the state entry.
  #
  # @!attribute [v] key
  #   @return [String] The unique state key.
  #
  # @!attribute [v] value
  #   @return [Hash, nil] The JSON-serialized state payload.
  #
  # @!attribute [v] created_at
  #   @return [Time, nil] The timestamp when the state was created.
  #
  # @!attribute [v] updated_at
  #   @return [Time, nil] The timestamp of the last update to the state.
end
