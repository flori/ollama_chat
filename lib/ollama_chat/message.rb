# An alias for the Ollama::Message class, allowing for extension
# while maintaining compatibility with factory methods like .from_hash.
OllamaChat::Message = Ollama::Message

# Mixin to provide write access to attributes that are read-only in the base
# class and add utility methods for content cleaning.
module OllamaChat::MessageMixin
  # Initializes a new message, ensuring the sender_name is set if provided.
  #
  # @param attributes [Hash] a hash of attributes to initialize the message.
  def initialize(**attributes)
    super
    if sender_name = attributes[:sender_name]
      self.sender_name = sender_name
    end
    if group_uuid = attributes[:group_uuid]
      self.group_uuid = group_uuid
    end
  end

  # @!attribute content
  #   @option setter [String] The content of the message.
  attr_writer :content

  # @!attribute thinking
  #   @option setter [String, nil] The thinking/reasoning process of the model.
  attr_writer :thinking

  # @!attribute images
  #   @option setter [Array<String>, nil] a list of image paths or data associated with the message.
  attr_writer :images

  # @!attribute sender_name
  #   @option getter [String, nil] The name of the message sender.
  #   @option setter [String, nil] The name of the message sender.
  attr_accessor :sender_name

  # @!attribute group_uuid
  #   @option getter [String] A UUIDv7 identifying the logical exchange (turn) this message belongs to.
  #   @option setter [String] The UUIDv7 for the logical exchange.
  attr_accessor :group_uuid

  # Ensures that the message has a `group_uuid` by generating a UUIDv7 if
  # missing. Returns self to allow for method chaining.
  #
  # @return [OllamaChat::Message] the message instance.
  def initialize_group_uuid
    self.group_uuid ||= SecureRandom.uuid_v7
    self
  end

  # Extracts the timestamp embedded within the UUIDv7 group identifier.
  #
  # @return [Time] The time the group was created, derived from the UUIDv7's
  #   time-ordered bits.
  def group_time
    Time.at((group_uuid.delete(?-)[0, 16].to_i(16) >> 16) / 1000.0) if group_uuid
  end

  # Returns true if the message is a tool message.
  #
  # @return [Boolean] true if the message has a present tool name, false
  #   otherwise.
  def tool?
    tool_name.present?
  end

  # Converts the message to a JSON-compatible hash, including the sender name and group UUID.
  #
  # @param a [Array] optional arguments for JSON conversion.
  # @return [Hash] a hash representation of the message.
  def as_json(*a)
    { sender_name:, group_uuid: }.compact | super
  end
end

# Reopening the aliased class to include the MessageMixin for enhanced
# functionality.
class OllamaChat::Message
  prepend OllamaChat::MessageMixin
end
