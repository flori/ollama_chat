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

  # Finds the message index at which compaction should cut.
  #
  # Walks non-system message groups (from +start+ onward) backward from
  # the tail, accumulating per-group token estimates. Returns the index of
  # the first message in the group whose addition causes the running total
  # to meet or exceed +keep_recent_tokens+. Messages from +start+ up to
  # that index are candidates for summarization; messages from that index
  # onward are preserved.
  #
  # If every group together still fits under the budget, the index of the
  # first group at or after +start+ is returned (signalling a no-op cut).
  #
  # @param start [Integer] the index at which to begin scanning (messages
  #   before this index are excluded; typically the position just past an
  #   existing summary message).
  # @param keep_recent_tokens [Integer] the token budget for preserved
  #   (recent) messages.
  # @return [Integer, nil] the cut index into +@messages+, or +nil+ if
  #   there are no non-system groups at or after +start+.
  def find_cut_point(start:, keep_recent_tokens:)
    groups = []
    @messages.each_with_index do |msg, i|
      next if msg.role == 'system'
      next if i < start
      tokens = msg.token_estimate(
        strip_thinking: @chat.think_strip.on?
      ).tokens
      uuid = msg.group_uuid
      if last = groups.last and last[:uuid] == uuid
        last[:tokens] += tokens
      else
        groups << { uuid:, start: i, tokens: }
      end
    end
    return nil if groups.empty?

    accumulated = 0
    groups.reverse_each do |group|
      accumulated += group[:tokens]
      return group[:start] if accumulated >= keep_recent_tokens
    end
    groups.first[:start]
  end

  # Finds the most recent summary message in the list.
  #
  # Scans backward from the tail for a message with
  # `role == 'tool'` and `tool_name == 'summary'`.
  #
  # @return [OllamaChat::Message, nil] the summary message, or
  #   `nil` if no summary has been inserted yet.
  def find_summary
    messages.reverse_each.find do |m|
      m.role == 'tool' && m.tool_name == 'summary'
    end
  end

  # Compacts the message list by summarizing old groups and inserting
  # a single summary tool message at the cut point.
  #
  # Resolves the keep-recent token budget from the current model's context
  # length, finds the cut point, summarizes all groups before it (passing
  # any existing summary as +previous_summary+ for iterative re-compaction),
  # then inserts the new summary at the cut point. Old groups remain in
  # the list for retrieval via +lookup_group+; the LLM context builder
  # skips them on the next call.
  #
  # @return [OllamaChat::Compaction::Result, nil] a +Result+ with
  #   before/after context estimates on success, or +nil+ if there was
  #   nothing to compact.
  def compact!
    ctx    = @chat.current_context_length
    budget = @chat.compact_ratio_tokens(:keep_recent, ctx)

    existing_summary = find_summary
    start = @messages.each_with_index.find do |m, i|
      m.role == 'tool' && m.tool_name == 'summary' and break i + 1
    end
    start ||= 0
    start   = start.clamp(0..(@messages.size - 1))

    # Cut among post-summary groups; the old summary is excluded
    # from the budget window by +start+.
    cut = find_cut_point(start:, keep_recent_tokens: budget)
    return nil if cut.nil? || cut <= 1

    candidates = @messages[start...cut]
      .reject { |m| m.role == 'system' }
      .reject { |m| m.role == 'tool' && m.tool_name == 'summary' }
    return nil if candidates.empty?

    cand_es = OllamaChat::TokenEstimator::Crude.new(
      candidates.sum { |m| m.content.to_s.bytesize }
    ).perform
    context_before = @chat.context_usage

    @chat.log(:info, 'Compaction: starting', data: {
      context_length: ctx,
      budget:         budget,
      cut_index:      cut,
      candidates:     candidates.size,
      candidate_bytes: cand_es.bytes_formatted,
      candidate_tokens: cand_es.tokens_formatted,
      previous_summary: existing_summary ? 'yes' : 'no',
    })

    summary_text, all_tool_entries = @chat.summarize_for_compaction(
      messages:         candidates,
      previous_summary: existing_summary,
    )

    compact_es = OllamaChat::TokenEstimator.estimate(summary_text.bytesize)
    @chat.log(:info, 'Compaction: summary generated', data: {
      summary_bytes:   compact_es.bytes_formatted,
      summary_tokens:  compact_es.tokens_formatted,
    })

    summary_msg = OllamaChat::Message.new(
      role:       'tool',
      tool_name:  'summary',
      content:    summary_text,
      tool_calls: all_tool_entries,
    ).initialize_group_uuid

    # Remove old summary (if any) and adjust cut for the shift.
    if existing_summary
      idx = @messages.index(existing_summary)
      @messages.delete_at(idx)
      cut -= 1 if idx < cut
    end

    @messages.insert(cut, summary_msg)
    @chat.log(:info, 'Compaction: done', data: {
      total_messages: @messages.size,
      summary_at:     cut,
    })
    sync

    OllamaChat::Compaction::Result.new(
      context_before:,
      context_after:  @chat.context_usage,
      candidates:     candidates.size,
      candidate_size: "#{cand_es.bytes_formatted} / " \
                      "#{cand_es.tokens_formatted}",
      summary_size:   "#{compact_es.bytes_formatted} / " \
                      "#{compact_es.tokens_formatted}",
      stored_total:   @chat.conversation_length,
    )
  end

  # Returns the messages that will actually be sent to the LLM.
  #
  # If no summary message exists, returns all messages (identical to
  # +to_ary+). If a summary is present, returns only the system prompt,
  # the summary, and everything after it — groups before the summary
  # are invisible to the model but remain in the list for
  # +lookup_group+ retrieval.
  #
  # @return [Array<OllamaChat::Message>] the messages to send to the LLM
  def compacted_messages
    idx = @messages.rindex do |m|
      m.role == 'tool' && m.tool_name == 'summary'
    end
    return to_ary if idx.nil?

    system = @messages.take_while { |m| m.role == 'system' }
    system + [@messages[idx]] + @messages[(idx + 1)..]
  end

  # Estimates the token and byte size of the messages that will actually
  # be sent to the LLM (i.e. +compacted_messages+).
  #
  # When no summary message exists this is identical to the full list.
  # When a summary is present, the pre-summary groups are excluded.
  #
  # Uses per-message +token_estimate+ which counts only text content
  # (and thinking, unless +think_strip+ is enabled), excluding images
  # and metadata scaffolding that would inflate a raw serialization.
  #
  # @return [OllamaChat::TokenEstimator::Estimate] the estimated token and
  #   byte counts for the effective LLM payload.
  def compacted_estimate_tokens
    strip = @chat.think_strip.on?
    bytes = compacted_messages.sum {
      _1.token_estimate(strip_thinking: strip).bytes
    }
    OllamaChat::TokenEstimator.estimate(bytes)
  end

  # Estimates the token and byte size of the **full** stored message
  # list (i.e. +@messages+), using per-message +token_estimate+.
  #
  # Unlike +Session#estimate_tokens+ which measures raw JSONL bytes
  # (including base64 images and JSON scaffolding), this counts only
  # text content and thinking (unless +think_strip+ is enabled).
  #
  # @return [OllamaChat::TokenEstimator::Estimate] the estimated token
  #   and byte counts for the full conversation payload.
  def full_estimate_tokens
    strip = @chat.think_strip.on?
    bytes = @messages.sum {
      _1.token_estimate(strip_thinking: strip).bytes
    }
    OllamaChat::TokenEstimator.estimate(bytes)
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

    role = Array(role)

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

  # Cleans the messages in the list by replacing them with stripped versions.
  # This is a destructive (mutating) operation.
  #
  # @param messages [Array<OllamaChat::Message>] the messages to clean.
  #   Defaults to all current messages.
  # @return [OllamaChat::MessageList] self to allow for method chaining.
  def clean_messages!(messages: @messages)
    @messages = clean_messages(messages:)
    self
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

  # Groups messages by their +group_uuid+, yielding an array of messages
  # belonging to the same conversational turn (User -> Assistant -> Tools).
  #
  # @param role [Array<String>] the message roles to include when grouping.
  #   Defaults to +%w[user assistant]+. Pass +%w[user assistant tool]+
  #   to include tool-result messages as well.
  # @param tool [Boolean] whether to include messages that carry a
  #   +tool_name+ (tool calls / responses) among +user+ / +assistant+ roles.
  #   Defaults to +false+.
  # @yield [Array<OllamaChat::Message>] an array of messages sharing the
  #   same +group_uuid+.
  # @return [Enumerator] if no block is given, returns an enumerator.
  def each_group(role: %w[ user assistant ], tool: false, &block)
    block or return enum_for(__method__, role:, tool:)
    each_message(role:, tool:).group_by(&:group_uuid).values.each(&block)
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
    current_group = nil
    @messages.reverse_each do |message|
      message.role == 'system' and next
      if current_group.nil?
        current_group = message.group_uuid
        i += 1
      elsif message.group_uuid == current_group
        i += 1
      else
        current_group = message.group_uuid
        m += 1
        if m < n
          i += 1
        else
          break
        end
      end
    end
    i > 0 && m == 0 and m = 1
    i.times do
      @messages.last.role == 'system' and next
      @messages.pop
    end
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
      system = @chat.prompt(system_name, context: 'system').to_s
    end
    @messages.reject! { |msg| msg.role == 'system' }
    templates_values = {
      persona:      @chat.default_persona_profile,
      runtime_info: (@chat.static_runtime_information if @chat.runtime_info.on?),
    }
    if new_system_prompt = system.full? { _1.to_s % templates_values }
      @system = new_system_prompt
      @messages.unshift(
        OllamaChat::Message.new(role: 'system', content: self.system).initialize_group_uuid
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
    es             = OllamaChat::TokenEstimator.estimate(current_system)
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
