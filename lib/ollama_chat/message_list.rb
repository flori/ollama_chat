# A collection class for managing chat messages with support for system
# prompts, paged output, and conversation history.
#
# This class provides functionality for storing, retrieving, and displaying
# chat messages in a structured manner. It handles system prompts separately
# from regular user and assistant messages, supports pagination for displaying
# conversations, and offers methods for manipulating message history including
# clearing, loading, saving, and dropping exchanges. The class integrates with
# Kramdown::ANSI for formatted output.
#
# @example Creating a new message list
#   chat = OllamaChat::Chat.new
#   messages = OllamaChat::MessageList.new(chat)
#
# @example Adding messages to the list
#   messages << OllamaChat::Message.new(role: 'user', content: 'Hello')
#   messages << OllamaChat::Message.new(role: 'assistant', content: 'Hi there!')
#
# @example Displaying conversation history
#   messages.list_conversation(5)  # Shows last 5 exchanges
#
# @example Clearing messages
#   messages.clear  # Removes all non-system messages
#
# @example Loading a saved conversation
#   messages.load_conversation('conversation.json')
#
# @example Saving current conversation
#   messages.save_conversation('my_conversation.json')
class OllamaChat::MessageList
  include Term::ANSIColor
  include OllamaChat::MessageFormat
  include OllamaChat::Pager
  include OllamaChat::Utils::ValueFormatter

  # The initialize method sets up the message list for an OllamaChat session.
  #
  # @param chat [ OllamaChat::Chat ] the chat object that this message list
  #   belongs to
  def initialize(chat)
    @chat     = chat
    @messages = []
  end

  # The system attribute reader returns the system prompt for the chat session.
  #
  # @attr_reader [ String, nil ] the current system prompt content or nil if not set
  attr_reader :system

  # The system_name attribute reader returns the name of the current system prompt.
  #
  # @attr_reader [ String, nil ] the name of the current system prompt or nil if not set
  attr_reader :system_name

  # The messages attribute reader returns the messages set for this object,
  # initializing it lazily if needed.
  #
  # The messages set is memoized, meaning it will only be created once per
  # object instance and subsequent calls will return the same
  # OllamaChat::MessageList instance.
  #
  # @attr_reader [OllamaChat::MessageList] A MessageList object containing all
  #   messages associated with this instance
  attr_reader :messages

  # Returns the number of messages stored in the message list.
  #
  # @return [ Integer ] The size of the message list.
  def size
    @messages.size
  end

  # The clear method removes all non-system messages from the message list.
  #
  # @return [ OllamaChat::MessageList ] self
  def clear(all: false)
    if all
      @messages.clear
    else
      @messages.delete_if { _1.role != 'system' }
    end
    sync
  end

  # The << operator appends a message to the list of messages and returns self.
  #
  # @param message [ OllamaChat::Message ] the message to append
  #
  # @return [ OllamaChat::MessageList ] self
  def <<(message)
    @messages << message
    sync
  end

  # Returns the last message from the conversation.
  #
  # @return [ OllamaChat::Message ] The last message in the conversation, or nil if
  #         there are no messages.
  def last
    @messages.last
  end

  # Find the *last* message that satisfies the supplied block.
  #
  # @param content [true, false] If `true`, skip messages that have no content
  #   (`m.content.present?` is `false`).  This is useful when you only care
  #   about messages that actually contain a payload (e.g. assistant
  #   replies, user queries, etc.).
  #
  # @yield [Message] yields each message in reverse order (from newest to
  #   oldest) until the block returns a truthy value.
  #
  # @yieldparam [OllamaChat::Message] message the current message being inspected
  # @yieldreturn [true, false] whether the message matches the criteria
  #
  # @return [OllamaChat::Message, nil] the first message that matches the
  #   block, or `nil` if none match.
  #
  # @example Find the last assistant message that contains content
  #   last_assistant = message_list.find_last(content: true) { |m| m.role == 'assistant' }
  #
  # @example Find the last user message regardless of content
  #   last_user = message_list.find_last { |m| m.role == 'user' }
  #
  # @note The method iterates in reverse order (`reverse_each`) so that the
  #   *most recent* matching message is returned. It also respects the
  #   `content` flag to skip empty messages, which is handy when the
  #   chat history contains empty messages e. g. when tool calling.
  def find_last(content: false, &block)
    @messages.reverse_each.find { |m|
      content and !m.content.present? and next
      block.(m)
    }
  end

  # Iterates over messages in the conversation, yielding those matching the
  # specified roles.
  #
  # @param role [Array<String>] the roles to include when iterating.
  #   Defaults to `['user', 'assistant']`.
  # @param tool [Boolean] Whether to include messages that are tool calls/responses.
  #   Defaults to `false`.
  # @yield [ message ] yields each matching message.
  #
  # @return [Enumerator] if no block is given, returns an enumerator.
  # @return [nil] if a block is given, returns nil after yielding all matching
  #   messages.
  def each_message(role: %w[ user assistant ], tool: false, &block)
    block or return enum_for(__method__, role:, tool:)

    @messages.each do |message|
      role.include?(message.role) or next
      !tool && message.tool? and next
      yield message
    end
    nil
  end

  # The load_conversation method loads a conversation from a file and populates
  # the message list.
  #
  # @param filename [ String ] the path to the file containing the conversation
  #
  # @return [ OllamaChat::MessageList ] self
  def load_conversation(filename)
    filename = Pathname.new(filename).expand_path
    unless filename.exist?
      STDERR.puts "File #{filename.to_s.inspect} doesn't exist. Choose another filename."
      return
    end
    @messages = OllamaChat::Utils::JSONJSONLIO.new(filename).read(
      jsonl_transform: method(:parse_message_from_json),
      json_transform:  method(:construct_message_from_hash)
    ).to_a
    sync
  end

  # The save_conversation method saves the current conversation to a file.
  #
  # @param filename [ String ] the path where the conversation will be saved
  # @param messages [Array<OllamaChat::Message>] the messages to save.
  #   Defaults to all current messages in the list.
  #
  # @return [ OllamaChat::MessageList ] self
  def save_conversation(filename, messages: @messages)
    OllamaChat::Utils::JSONJSONLIO.new(filename).write(collection: messages)
    self
  end

  # Returns a new list of messages with the content replaced by their stripped
  # versions.
  # This is used to create a "clean" version of the conversation for saving or
  # displaying without mutating the original message objects.
  #
  # @param messages [Array<OllamaChat::Message>] the list of messages to clean
  # @return [Array<OllamaChat::Message>] a new array containing duplicated
  #   messages with stripped content
  def clean_messages(messages: @messages)
    messages.map do |message|
      message = message.dup
      message.content = '' if message.tool?
      message.images = nil
      message
    end
  end

  # Displays the most recent messages from the conversation history.
  #
  # This method prints a specified number of trailing messages to the console
  # using the pager for better readability. Tool messages are automatically
  # excluded from the output. If no count is provided, the entire
  # conversation is displayed.
  #
  # @param last [Integer, nil] The number of recent messages to display.
  #   Defaults to the total size of the messages list if nil.
  # @param think_loud [Boolean] Whether to force show or suppress thinking content.
  #   Defaults to the global chat setting.
  #
  # @return [OllamaChat::MessageList] self, allowing for method chaining.
  def list_conversation(last = nil, think_loud: @chat.think_loud.on?)
    messages = @messages.reject(&:tool?)
    last = (last || messages.size).clamp(0, messages.size)
    messages = messages[-last..-1].to_ary
    use_pager do |output|
      messages = clean_messages(messages:)
      messages = messages.with_infobar(
        output:  STDERR,
        label:   'Message',
        total:   messages.size,
        message: @chat.infobar_message,
      )
      messages.each do |message|
        output.puts message_text_for(message, think_loud:)
        +infobar
      end
    end
    self
  end

  # Displays the most recent messages that were not authored by the user.
  #
  # This is particularly useful for quickly reviewing the assistant's last
  # responses without having to scroll through the user's own input.
  # Output is routed through the pager.
  #
  # @param n [Integer, nil] The number of non-user messages to display.
  #   Defaults to 1 if not specified.
  # @param pager [Boolean] whether to use a pager for output (default: true).
  # @param think_loud [Boolean] Whether to force show or suppress thinking content.
  #   Defaults to the global chat setting.
  #
  # @return [OllamaChat::MessageList, nil] self if messages were displayed,
  #   or nil if no valid messages were found to show.
  def show_last(n = nil, pager: true, think_loud: @chat.think_loud.on?)
    n ||= 1
    messages = @messages.reject { |message| message.role == 'user' }
    n = n.clamp(0..messages.size)
    n <= 0 and return
    last_message_user_message = (last.content if last&.role == 'user')
    outputter = -> output do
      last_messages = messages[-n..-1].to_a
      last_messages = last_messages.with_infobar(
        output:  STDERR,
        label:   'Message',
        total:   last_messages.size,
        message: @chat.infobar_message,
      )
      last_messages.each do |message|
        output.puts message_text_for(message, think_loud:)
        +infobar
      end
    ensure
      if last_message_user_message
        message_content = Kramdown::ANSI::Width.truncate(
          last_message_user_message.inspect,
          length: Tins::Terminal.columns * 0.9
        )
        msg = <<~EOT

          ⚠️ Last message is actually a #{bold{'user message'}}, see:

          #{message_content}

          You might want to /drop it or /regenerate it.
        EOT
        output.puts msg
      end
    end
    if pager
      use_pager(&outputter)
    else
      outputter.(STDOUT)
    end
    self
  end

  # Removes the last `n` conversation exchanges from the message list.
  #
  # An exchange is typically defined as a pair of user and assistant messages.
  # This method iterates backwards through the history and removes messages
  # until the requested number of exchanges have been dropped. It will stop
  # if it encounters a system message.
  #
  # @param n [Object] The number of exchanges to drop.
  #
  # @return [Integer] The actual number of exchanges that were dropped.
  #
  # @note This method automatically synchronizes the message list with the
  #   session store.
  def drop(n)
    n = n.to_i.clamp(1, Float::INFINITY)
    i = 0
    m = 0
    @messages.reverse_each.each_cons(2) do |message, before|
      message.role == 'system' and break
      if message.role == 'assistant'
        i += 1
      elsif message.role == 'user'
        i += 1
        next if before.role == 'user'
        m += 1
      end
      m >= n and break
    end
    i.times { @messages.pop }
    STDOUT.puts "Dropped the last #{m} exchanges."
    m
  ensure
    sync
  end

  # Sets the system prompt for the chat session.
  #
  # @param system_name [String, nil] The name of the new system prompt. If
  #   `nil` or `false`, clears the system prompt.
  #
  # @return [OllamaChat::MessageList] Returns `self` to allow chaining of
  #   method calls.
  #
  # @note This method:
  #   - Removes all existing system prompts from the message list
  #   - Adds the new system prompt to the beginning of the message list if
  #     provided
  #   - Handles edge cases such as clearing prompts when `system` is `nil` or
  #     `false`
  def set_system_prompt(system_name)
    @system_name = system_name
    if system_name == 'model_default'
      system = @chat.model_default_system_prompt.to_s
    else
      system = @chat.system_prompt(system_name).to_s
    end
    @messages.reject! { |msg| msg.role == 'system' }
    templates_values = {
      persona:      @chat.default_persona_profile,
      runtime_info: (@chat.static_runtime_information if @chat.runtime_info.on?),
    }
    if new_system_prompt = system.full? { _1.to_s % templates_values }
      @system = new_system_prompt
      @messages.unshift(
        OllamaChat::Message.new(role: 'system', content: self.system)
      )
    else
      @system = nil
    end
    sync
  end

  # The show_system_prompt method displays the system prompt configured for the
  # chat session.
  #
  # It retrieves the system prompt from the @system instance variable, parses
  # it using Kramdown::ANSI, and removes any trailing newlines. If the
  # resulting string is empty, the method returns immediately.
  #
  # Otherwise, it prints a formatted message to the console, including the
  # configured system prompt and its length in characters.
  #
  # @return [self, NilClass] nil if the system prompt is empty, otherwise self.
  def show_system_prompt
    current_system = system.to_s
    size_bytes     = current_system.size
    es             = OllamaChat::TokenEstimator.estimate(size_bytes)
    system_prompt  = @chat.kramdown_ansi_parse(current_system).
       gsub(/\n+\z/, '').full?
    if system_prompt.blank?
      if current_system.present?
        system_prompt = current_system
      else
        return
      end
    end
    use_pager do |output|
      output.puts <<~EOT
      Configured system prompt is:
      #{system_prompt}

      System prompt name:   #{bold{system_name}}
      System prompt length: 👾#{es.bytes_formatted} 🧩#{es.tokens_formatted}
      EOT
    end
    self
  end

  # The to_ary method converts the message list into an array of
  # OllamaChat::Message objects.
  #
  # @return [Array] An array of OllamaChat::Message objects representing the
  #   messages in the list.
  def to_ary
    @messages.dup
  end

  # Writes each message in the conversation to the output as a JSON line.
  #
  # @param output [IO] the output stream to write the JSON lines
  # @param messages [Array<OllamaChat::Message>] the messages to write.
  #   Defaults to all current messages in the list.
  # @return [OllamaChat::MessageList] returns self to allow for method chaining
  def write_conversation_jsonl(output, messages: @messages)
    OllamaChat::Utils::JSONJSONLIO.new('as.jsonl').write_io(output:, collection: messages)
    self
  end

  # Loads conversation messages from a JSONL (JSON Lines) input stream. Each
  # line in the input is expected to be a valid JSON representation of a
  # message. The method parses each line and adds the resulting message to
  # the current conversation.
  #
  # @param input [IO] the input stream containing JSONL formatted messages
  # @return [OllamaChat::MessageList] returns self to allow for method chaining
  def read_conversation_jsonl(input)
    @messages = OllamaChat::Utils::JSONJSONLIO.new('as.jsonl').read_io(
      input:,
      jsonl_transform: method(:parse_message_from_json)
    ).to_a
    self
  end

  # Removes all images from all messages in the current list.
  #
  # @return [OllamaChat::MessageList] returns self to allow for method chaining
  def clear_images
    @messages.each do |message|
      message.images = nil
    end
    sync
  end

  private

  # The config method provides access to the chat configuration object.
  #
  # @return [ Object ] the configuration object associated with the chat instance
  def config
    @chat.config
  end

  # The message_text_for method generates formatted text representation of a
  # message including its role, content, thinking annotations, and associated
  # images.
  # It applies color coding to different message roles and uses markdown
  # parsing when enabled. The method also handles special formatting for
  # thinking annotations and image references within the message.
  #
  # @param message [Object] the message object containing role, content, thinking, and images
  # @param think_loud [Boolean] Whether to force show or suppress thinking content.
  #   Defaults to the global chat setting.
  #
  # @return [String] the formatted text representation of the message
  def message_text_for(message, think_loud: @chat.think_loud.on?)
    thinking = if think_loud
                 think_annotate(think_loud:) do
                   message.thinking.full? { @chat.markdown.on? ? @chat.kramdown_ansi_parse(_1) : _1 }
                 end
               end
    content       = message.content.full? { @chat.markdown.on? ? @chat.kramdown_ansi_parse(_1) : _1 }
    message_text  = display_sender(message)
    if thinking
      message_text += [ ?:, thinking, talk_annotate(think_loud:) { content } ].compact.
        map(&:chomp) * ?\n
    else
      message_text += ":\n#{content}"
    end
    message_text
  end

  # Loads a conversation from a JSONL (JSON Lines) file.
  #
  # @param filename [Pathname] the path to the JSONL file
  # @return [Array<OllamaChat::Message>] an array of messages
  def load_conversation_jsonl(filename)
    filename.each_line.map {
      parse_message_from_json(_1)
    }
  end

  # Saves the conversation to a JSONL (JSON Lines) file.
  #
  # @param filename [Pathname] the path to the JSONL file
  # @param messages [Array] the messages to save
  # @return [OllamaChat::MessageList] self
  def save_conversation_jsonl(filename, messages: @messages)
    filename.open(?w) do |output|
      write_conversation_jsonl(output, messages:)
    end
    self
  end

  # Parse a message from a JSON string.
  #
  # @param string [String] the JSON string representing the message
  # @return [OllamaChat::Message] a new message instance created from the JSON data
  def parse_message_from_json(string)
    construct_message_from_hash(JSON.parse(string))
  end

  # Constructs a message instance from a hash, ensuring that a 'content' key
  # is present even if it is nil.
  #
  # @param hash [Hash] the message data
  # @return [OllamaChat::Message] a new message instance
  def construct_message_from_hash(hash)
    OllamaChat::Message.from_hash(hash | { 'content' => nil })
  end

  # Synchronizes the message list state with the active chat session.
  #
  # This method triggers the persistence of the current messages into the
  # database via the associated `@chat` instance, ensuring that any
  # recent mutations (like adding, clearing, or dropping messages) are
  # immediately captured in the persistent session store.
  #
  # @return [ OllOamaChat::MessageList ] the current instance to allow for
  #   method chaining.
  def sync
    @chat.store_messages_in_session
    self
  end
end
