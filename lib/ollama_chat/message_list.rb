# A collection class for managing chat messages with support for system
# prompts, paged output, and conversation history.

# This class provides functionality for storing, retrieving, and displaying
# chat messages in a structured manner. It handles system prompts separately
# from regular user and assistant messages, supports pagination for displaying
# conversations, and offers methods for manipulating message history including
# clearing, loading, saving, and dropping exchanges. The class integrates with
# Kramdown::ANSI for formatted output and supports location information in
# system messages.

# @example Creating a new message list
#   chat = OllamaChat::Chat.new
#   messages = OllamaChat::MessageList.new(chat)
#
# @example Adding messages to the list
#   messages << Ollama::Message.new(role: 'user', content: 'Hello')
#   messages << Ollama::Message.new(role: 'assistant', content: 'Hi there!')
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

  # The initialize method sets up the message list for an OllamaChat session.
  #
  # @param chat [ OllamaChat::Chat ] the chat object that this message list
  # belongs to
  def initialize(chat)
    @chat     = chat
    @messages = []
  end

  # The system attribute reader returns the system prompt for the chat session.
  #
  # @attr_reader [ String, nil ] the current system prompt content or nil if not set
  attr_reader :system

  # The messages attribute reader returns the messages set for this object,
  # initializing it lazily if needed.
  #
  # The messages set is memoized, meaning it will only be created once per
  # object instance and subsequent calls will return the same
  # OllamaChat::MessageList instance.
  #
  # @attr_reader [OllamaChat::MessageList] A MessageList object containing all
  # messages associated with this instance
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
  def clear
    @messages.delete_if { _1.role != 'system' }
    self
  end

  # The << operator appends a message to the list of messages and returns self.
  #
  # @param message [ Ollama::Message ] the message to append
  #
  # @return [ OllamaChat::MessageList ] self
  def <<(message)
    @messages << message
    self
  end

  # Returns the last message from the conversation.
  #
  # @return [ Ollama::Message ] The last message in the conversation, or nil if
  #         there are no messages.
  def last
    @messages.last
  end

  # The second_last method returns the second-to-last message from the
  # conversation if there are more than one non-system messages.
  #
  # @return [ Ollama::Message ] the second-to-last message
  def second_last
    if @messages.reject { _1.role == 'system' }.size > 1
      @messages[-2]
    end
  end

  # The load_conversation method loads a conversation from a file and populates
  # the message list.
  #
  # @param filename [ String ] the path to the file containing the conversation
  #
  # @return [ OllamaChat::MessageList ] self
  def load_conversation(filename)
    unless File.exist?(filename)
      STDERR.puts "File #{filename.inspect} doesn't exist. Choose another filename."
      return
    end
    @messages =
      File.open(filename, 'r') do |output|
        JSON(output.read).map { Ollama::Message.from_hash(_1) }
      end
    self
  end

  # The save_conversation method saves the current conversation to a file.
  #
  # @param filename [ String ] the path where the conversation will be saved
  #
  # @return [ OllamaChat::MessageList ] self
  def save_conversation(filename)
    File.open(filename, ?w) do |output|
      output.puts JSON(@messages)
    end
    self
  end

  # The list_conversation method displays the last n messages from the conversation.
  #
  # @param last [ Integer ] the number of messages to display (default: nil)
  #
  # @return [ OllamaChat::MessageList ]
  def list_conversation(last = nil)
    last = (last || @messages.size).clamp(0, @messages.size)
    use_pager do |output|
      @messages[-last..-1].to_a.each do |message|
        output.puts message_text_for(message)
      end
    end
    self
  end

  # The show_last method displays the text of the last message if it is not
  # from the user. It uses a pager for output and returns the instance itself.
  #
  # @return [ OllamaChat::MessageList ] returns the instance of the class
  def show_last(n = nil)
    n ||= 1
    messages = @messages.reject { |message| message.role == 'user' }
    n = n.clamp(0..messages.size)
    n <= 0 and return
    use_pager do |output|
      messages[-n..-1].to_a.each do |message|
        output.puts message_text_for(message)
      end
    end
    self
  end

  # Removes the last `n` exchanges from the message list. An exchange consists
  # of a user and an assistant message. If only a single user message is
  # present at the end, it will be removed first before proceeding with
  # complete exchanges.
  #
  # @param n [Integer] The number of exchanges to remove.
  # @return [Integer] The actual number of complete exchanges removed.
  #                   This may be less than `n` if there are not enough messages.
  #
  # @note
  #   - System messages are preserved and not considered part of an exchange.
  #   - If only one incomplete exchange (a single user message) exists, it will
  #     be dropped first before removing complete exchanges.
  def drop(n)
    n = n.to_i.clamp(1, Float::INFINITY)
    non_system_messages = @messages.reject { _1.role == 'system' }
    if non_system_messages&.last&.role == 'user'
      @messages.pop
      n -= 1
    end
    if n == 0
      STDOUT.puts "Dropped the last exchange."
      return 1
    end
    if non_system_messages.empty?
      STDOUT.puts "No more exchanges can be dropped."
      return 0
    end
    m = 0
    while @messages.size > 1 && n > 0
      @messages.pop(2)
      m += 1
      n -= 1
    end
    STDOUT.puts "Dropped the last #{m} exchanges."
    m
  end

  # Sets the system prompt for the chat session.
  #
  # @param system [String, nil] The new system prompt. If `nil` or `false`, clears the system prompt.
  #
  # @return [OllamaChat::MessageList] Returns `self` to allow chaining of method calls.
  #
  # @note This method:
  #   - Removes all existing system prompts from the message list
  #   - Adds the new system prompt to the beginning of the message list if provided
  #   - Handles edge cases such as clearing prompts when `system` is `nil` or `false`
  def set_system_prompt(system)
    @messages.reject! { |msg| msg.role == 'system' }
    if new_system_prompt = system.full?(:to_s)
      @system = new_system_prompt
      @messages.unshift(
        Ollama::Message.new(role: 'system', content: self.system)
      )
    else
      @system = nil
    end
    self
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
    system_prompt = @chat.kramdown_ansi_parse(system.to_s).gsub(/\n+\z/, '').full?
    system_prompt or return
    STDOUT.puts <<~EOT
      Configured system prompt is:
      #{system_prompt}

      System prompt length: #{bold{system_prompt.size}} characters.
    EOT
    self
  end

  # The to_ary method converts the message list into an array of
  # Ollama::Message objects. If location support was enabled and the message
  # list contains a system message, the system messages is decorated with the
  # curent location, time, and unit preferences.
  #
  # @return [Array] An array of Ollama::Message objects representing the
  # messages in the list.
  def to_ary
    location = at_location.full?
    add_system = !!location
    result = @messages.map do |message|
      if message.role == 'system' && location
        add_system = false
        content = message.content + "\n\n#{location}"
        Ollama::Message.new(role: message.role, content:)
      else
        message
      end
    end
    if add_system
      prompt = @chat.config.system_prompts.assistant?
      content = [ prompt, location ].compact * "\n\n"
      message = Ollama::Message.new(role: 'system', content:)
      result.unshift message
    end
    result
  end

  # The at_location method returns the location/time/units information as a
  # string if location is enabled.
  #
  # @return [ String ] the location information
  def at_location
    if @chat.location.on?
      location_name            = config.location.name
      location_decimal_degrees = config.location.decimal_degrees * ', '
      localtime                = Time.now.iso8601
      units                    = config.location.units
      config.prompts.location % {
        location_name:, location_decimal_degrees:, localtime:, units:,
      }
    end.to_s
  end

  private

  # The config method provides access to the chat configuration object.
  #
  # @return [ Object ] the configuration object associated with the chat instance
  def config
    @chat.config
  end

  # The determine_pager_command method identifies an appropriate pager command
  # for displaying content.
  # It first checks for a default pager specified by the PAGER environment variable.
  # If no default is found, it attempts to locate 'less' or 'more' in the
  # system PATH as fallback options.
  # The method returns the selected pager command, ensuring it includes the
  # '-r' flag for proper handling of raw control characters when a fallback
  # pager is used.
  def determine_pager_command
    OllamaChat::EnvConfig::PAGER?
  end

  # The use_pager method wraps the given block with a pager context.
  # If the output would exceed the terminal's line capacity, it pipes the content
  # through an appropriate pager command (like 'less' or 'more').
  #
  # @yield A block that yields an IO object to write output to
  # @yieldparam [IO] the IO object to write to
  def use_pager
    command       = determine_pager_command
    output_buffer = StringIO.new
    yield output_buffer
    messages = output_buffer.string
    Kramdown::ANSI::Pager.pager(command:, lines: messages.count(?\n)) do |output|
      output.puts messages
    end
  end

  # The message_text_for method generates formatted text representation of a
  # message including its role, content, thinking annotations, and associated
  # images.
  # It applies color coding to different message roles and uses markdown
  # parsing when enabled. The method also handles special formatting for
  # thinking annotations and image references within the message.
  #
  # @param message [Object] the message object containing role, content, thinking, and images
  #
  # @return [String] the formatted text representation of the message
  def message_text_for(message)
    role_color = case message.role
                 when 'user' then 172
                 when 'assistant' then 111
                 when 'system' then 213
                 else 210
                 end
    thinking = if @chat.think?
                 think_annotate do
                   message.thinking.full? { @chat.markdown.on? ? @chat.kramdown_ansi_parse(_1) : _1 }
                 end
               end
    content = message.content.full? { @chat.markdown.on? ? @chat.kramdown_ansi_parse(_1) : _1 }
    message_text = message_type(message.images) + " "
    message_text += bold { color(role_color) { message.role } }
    if thinking
      message_text += [ ?:, thinking, talk_annotate { content } ].compact.
        map { _1.chomp } * ?\n
    else
      message_text += ":\n#{content}"
    end
    message.images.full? { |images|
      message_text += "\nImages: " + italic { images.map(&:path) * ', ' }
    }
    message_text
  end
end
