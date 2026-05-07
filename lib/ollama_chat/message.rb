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

  # Returns the content of the message with internal JSON markers stripped away.
  #
  # @return [String] The cleaned content.
  def stripped_content
    text = strip_internal_marker(:ollama_chat_retrieval_snippets)
    strip_internal_marker(:ollama_chat_runtime_information, text)
  end

  attr_accessor :sender_name

  def as_json(*a)
    if sender_name
      { sender_name: } | super
    else
      super
    end
  end

  private

  # Removes lines that are JSON objects containing the given key.
  #
  # @param name [String, Symbol] the key to look for in each line.
  # @param text [String] the text to process (defaults to the message content).
  # @return [String] the text with matching marker lines removed.
  def strip_internal_marker(name, text = content)
    return if text.nil?
    name = name.to_s
    text.each_line.map do |line|
      JSON(line).fetch(name) and next
    rescue
      line
    end.compact.join
  end
end

# Reopening the aliased class to include the MessageMixin for enhanced
# functionality.
class OllamaChat::Message
  prepend OllamaChat::MessageMixin
end
