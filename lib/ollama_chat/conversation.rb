# A module that provides conversation persistence functionality for the
# OllamaChat::Chat class.
#
# This module encapsulates the logic for saving and loading chat conversations
# to/from JSON files. It delegates the actual file operations to the `messages`
# object, which is expected to respond to `save_conversation` and
# `load_conversation` methods.
#
# @example Save a conversation
#   chat.save_conversation('my_chat.json')
#
# @example Load a conversation
#   chat.load_conversation('my_chat.json')
module OllamaChat::Conversation
  # Saves the current conversation to a JSON file.
  #
  # This method delegates to the `messages` object's `save_conversation`
  # method, which handles the actual serialization of messages into JSON
  # format.
  #
  # @param filename [String] The path to the file where the conversation should
  #   be saved
  #
  # @example Save conversation with explicit filename
  #   chat.save_conversation('conversations/2023-10-15_my_session.json')
  def save_conversation(filename)
    File.exist?(filename) &&
      ask?(prompt: "File #{filename.inspect} already exists, overwrite? (y/n) ") !~ /\Ay/i and
      return
    if messages.save_conversation(filename)
      STDOUT.puts "Saved conversation to #{filename.inspect}."
    else
      STDERR.puts "Saving conversation to #{filename.inspect} failed."
    end
  end

  # Loads a conversation from a JSON file and replaces the current message
  # history.
  #
  # This method delegates to the `messages` object's `load_conversation`
  # method, which handles deserialization of messages from JSON format. After
  # loading, if there are more than one message, it lists the last two messages
  # for confirmation.
  #
  # @param filename [String] The path to the file containing the conversation
  #   to load
  #
  # @example Load a conversation from a specific file
  #   chat.load_conversation('conversations/2023-10-15_my_session.json')
  def load_conversation(filename)
    success = messages.load_conversation(filename)
    if messages.size > 1
      messages.list_conversation(2)
    end
    if success
      STDOUT.puts "Loaded conversation from #{filename.inspect}."
    else
      STDERR.puts "Loading conversation from #{filename.inspect} failed."
    end
  end
end
