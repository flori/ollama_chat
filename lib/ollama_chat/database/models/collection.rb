# Represents a document collection stored in the database, allowing for
# dynamic management of documentrix collections.
#
# This model stores collections with a name, description, and patterns
# for automatic file discovery and synchronization.
class OllamaChat::Database::Models::Collection < Sequel::Model(OllamaChat::DB)
  include OllamaChat::Database::Duplicatable

  plugin :timestamps, update_on_create: true
  plugin :serialization, :json, :patterns
  plugin :validation_helpers

  # Validates the collection.
  #
  # Ensures that the `name` is present and unique.
  def validate
    super
    validates_presence :name
    validates_unique :name
    validates_presence :description
  end

  # Sets the chat instance associated with this collection.
  #
  # This allows the collection to interact with the chat's document
  # store during lifecycle events, such as cleanup upon destruction.
  #
  # @param chat [OllamaChat::Chat] the chat instance
  attr_writer :chat

  # Hook to clean up the corresponding Documentrix collection when
  # the database record is destroyed.
  #
  # This ensures that we don't leave orphaned vector data in the
  # Documentrix engine when the underlying collection record is removed.
  def after_destroy
    super
    @chat or return
    @chat.switch_collection(name) do
      @chat.documents.clear
    end
    true
  end

  # Synchronizes the database records with the Documentrix collections.
  #
  # This method iterates through the configured collections in the chat's
  # document store and ensures that every collection has a corresponding
  # record in the database. If a collection exists in Documentrix but not
  # in the database, a new record is created with a default description.
  #
  # @param chat [OllamaChat::Chat] the chat instance providing the configuration
  def self.sync(chat)
    chat.documents.collections.each do |name|
      where(name: name.to_s).first and next
      create(
        name:        name.to_s,
        description: "TODO: Describe collection #{name}",
        patterns:    []
      )
    end
  end

  # @!attribute [v] id
  #   @return [Integer] The primary key for the collection entry.
  #
  # @!attribute [v] name
  #   @return [String] The name of the collection (matches documentrix name).
  #
  # @!attribute [v] description
  #   @return [String, nil] A description of the collection.
  #
  # @!attribute [v] patterns
  #   @return [Array, nil] An array of glob patterns for file discovery.
  #
  # @!attribute [v] created_at
  #   @return [Time, nil] The timestamp when the collection was created.
  #
  # @!attribute [v] updated_at
  #   @return [Time, nil] The timestamp of the last update to the collection.
end
