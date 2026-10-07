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
  private

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
  def save_conversation(filename, clean: false)
    cleaned = 'cleaned ' if clean
    filename = Pathname.new(filename)
    should_overwrite?(filename) or return
    messages = clean ? self.messages.clean_messages : self.messages.messages
    if self.messages.save_conversation(filename, messages:)
      feedback("Saved #{cleaned}conversation to #{filename.to_s.inspect}.", type: :info)
    else
      feedback("Saving #{cleaned}conversation to "\
               "#{filename.to_s.inspect} failed.", type: :warn)
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
      feedback("Loaded conversation from #{filename.to_s.inspect}.", type: :info)
    else
      feedback("Loading conversation from "\
               "#{filename.to_s.inspect} failed.", type: :warn)
    end
  end

  # Selectively cleans parts of the current conversation.
  #
  # Presents an accumulating chooser of cleanable targets:
  # tool content, images, thinking, messages, history, links.
  # The user picks one or more (or [ALL]), confirms, and the
  # selected items are cleared.
  def conversation_clean
    options = %w[ tools images thinking messages history links ]

    selected = Set.new
    choose_with_state do
      loop do
        remaining = options - selected.to_a
        entries   = (remaining.empty? ? [] : ['[ALL]'] + remaining) + ['[DONE]']
        choice    = choose_entry(entries, prompt: 'What to clean from conversation? %s')
        case choice
        when nil, '[DONE]'
          break
        when '[ALL]'
          selected.merge(remaining)
          break
        else
          selected.add(choice)
        end
      end
    end

    return feedback('Cancelled, nothing selected.', type: :cancel) if selected.empty?

    what = selected.map { |s| bold{s} }.to_a

    unless confirm?(
      prompt: "🔔 Clean #{what * ', '} from conversation? (y/n) ",
      yes: /\Ay/i
    )
      return feedback('Denied.', type: :denied)
    end

    field_options = %w[ tools images thinking ].select { selected.include?(_1) }
    messages.clear if selected.include?('messages')
    messages.clean_messages!(what: field_options.map(&:to_sym)) unless field_options.empty?
    clear_history if selected.include?('history')
    links.clear if selected.include?('links')

    session_sync
    feedback("Cleaned #{what * ', '} from conversation.", type: :info)
  end
end
