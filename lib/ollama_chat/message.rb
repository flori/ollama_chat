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

  # Converts the message to a JSON-compatible hash, including the sender name if present.
  #
  # @param a [Array] optional arguments for JSON conversion.
  # @return [Hash] a hash representation of the message.
  def as_json(*a)
    if sender_name
      { sender_name: } | super
    else
      super
    end
  end
end

# Reopening the aliased class to include the MessageMixin for enhanced
# functionality.
class OllamaChat::Message
  prepend OllamaChat::MessageMixin
end
