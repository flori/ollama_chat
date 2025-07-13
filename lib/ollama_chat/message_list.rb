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

  attr_reader :system

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
      STDOUT.puts "File #{filename} doesn't exist. Choose another filename."
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
    if File.exist?(filename)
      STDOUT.puts "File #{filename} already exists. Choose another filename."
      return
    end
    File.open(filename, 'w') do |output|
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
      @messages[-last..-1].to_a.each do |m|
        role_color = case m.role
                     when 'user' then 172
                     when 'assistant' then 111
                     when 'system' then 213
                     else 210
                     end
        thinking = if @chat.think.on?
                     think_annotate do
                       m.thinking.full? { @chat.markdown.on? ? Kramdown::ANSI.parse(_1) : _1 }
                     end
                   end
        content = m.content.full? { @chat.markdown.on? ? Kramdown::ANSI.parse(_1) : _1 }
        message_text = message_type(m.images) + " "
        message_text += bold { color(role_color) { m.role } }
        if thinking
          message_text += [ ?:, thinking, talk_annotate { content } ].compact.
            map { _1.chomp } * ?\n
        else
          message_text += ":\n#{content}"
        end
        m.images.full? { |images|
          message_text += "\nImages: " + italic { images.map(&:path) * ', ' }
        }
        output.puts message_text
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
    system_prompt = Kramdown::ANSI.parse(system.to_s).gsub(/\n+\z/, '').full?
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

  def config
    @chat.config
  end

  def determine_pager_command
    default_pager = ENV['PAGER'].full?
    if fallback_pager = `which less`.chomp.full? || `which more`.chomp.full?
      fallback_pager << ' -r'
    end
    default_pager || fallback_pager
  end

  def use_pager
    command       = determine_pager_command
    output_buffer = StringIO.new
    yield output_buffer
    messages = output_buffer.string
    Kramdown::ANSI::Pager.pager(command:, lines: messages.count(?\n)) do |output|
      output.puts messages
    end
  end
end
