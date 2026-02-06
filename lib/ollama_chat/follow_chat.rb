# A class that handles chat responses and manages the flow of conversation
# between the user and Ollama models.
#
# This class is responsible for processing Ollama API responses, updating
# message history, displaying formatted output to the terminal, and managing
# voice synthesis for spoken responses. It acts as a handler for streaming
# responses and ensures proper formatting and display of both regular content
# and thinking annotations.
#
# @example Processing a chat response
#   follow_chat = OllamaChat::FollowChat.new(chat: chat_instance, messages: message_list)
#   follow_chat.tool_call(response)
class OllamaChat::FollowChat
  include Ollama
  include Ollama::Handlers::Concern
  include Term::ANSIColor
  include OllamaChat::MessageFormat

  # Initializes a new instance of OllamaChat::FollowChat.
  #
  # @param [OllamaChat::Chat] chat The chat object, which represents the
  #   conversation context.
  # @param [#to_a] messages A collection of message objects, representing the
  #   conversation history.
  # @param [String] voice (optional) to speek with if any.
  # @param [IO] output (optional) The output stream where terminal output
  #   should be printed. Defaults to STDOUT.
  #
  # @return [OllamaChat::FollowChat] A new instance of OllamaChat::FollowChat.
  def initialize(chat:, messages:, voice: nil, output: STDOUT)
    super(output:)
    @chat        = chat
    @output.sync = true
    @say         = voice ? Handlers::Say.new(voice:) : NOP
    @messages    = messages
    @user        = nil
  end

  # Returns the conversation history (an array of message objects).
  #
  # @return [OllamaChat::MessageList<Ollama::Message>] The array of messages in
  #   the conversation.
  attr_reader :messages

  # Invokes the chat flow based on the provided Ollama server response.
  #
  # The response is expected to be a parsed JSON object containing information
  # about the user input and the assistant's response.
  #
  # If the response indicates an assistant message, this method:
  #   1. Ensures that an assistant response exists in the message history (if
  #      not already present).
  #   2. Updates the last message with the new content and thinking (if
  #      applicable).
  #   3. Displays the formatted terminal output for the user.
  #   4. Outputs the voice response (if configured).
  #
  # Regardless of whether an assistant message is present, this method also
  # outputs evaluation statistics (if applicable).
  #
  # @param [Ollama::Response] response The parsed JSON response from the Ollama
  #   server.
  #
  # @return [OllamaChat::FollowChat] The current instance for method chaining.
  def call(response)
    debug_output(response)

    if response&.message&.role == 'assistant'
      ensure_assistant_response_exists
      update_last_message(response)
      if @chat.stream.on?
        display_formatted_terminal_output
      else
        if display_output
          display_formatted_terminal_output
        end
      end
      @say.call(response)
    end

    output_eval_stats(response)

    handle_tool_calls(response)

    self
  end

  private

  # The handle_tool_calls method processes tool calls from a response and
  # executes them.
  #
  # This method checks if the response contains tool calls, and if so, iterates
  # through each tool call to execute the corresponding tool from the
  # registered tools. The results of the tool execution are stored in the
  # chat's tool_call_results hash using the tool name as the key.
  #
  # @param response [Object] the response object containing tool calls to
  #   process
  def handle_tool_calls(response)
    return unless response.message.ask_and_send(:tool_calls)

    response.message.tool_calls.each do |tool_call|
      name = tool_call.function.name
      unless @chat.config.tools.attribute_set?(name)
        STDERR.printf("Unknown tool named %s ignored => Skip.\n", name)
        next
      end
      STDOUT.puts
      confirmed = true
      if @chat.config.tools[name].confirm?
        prompt = "I want to execute tool %s(%s)\n\nConfirm? (y/n) " % [
          bold { name },
          italic { JSON(tool_call.function.arguments) },
        ]
        confirmed = @chat.ask?(prompt:) =~ /\Ay/i
      end
      Infobar.busy(
        label: 'Executing tool %s' % name,
        frames: :braille7,
        output: STDOUT,
      ) do
        result = nil
        if confirmed
          infobar.printf(
            "%s Execution of tool %s(%s) confirmed.\n",
            ?✅,
            bold { name },
            italic { JSON(tool_call.function.arguments) }
          )
          result = OllamaChat::Tools.registered[name].
            execute(tool_call, chat: @chat, config: @chat.config)
        else
          result = JSON(
            message: 'User denied confirmation!',
            resolve: 'You **MUST** ask the user for instructions on how to proceed!!!',
          )
        end
        @chat.tool_call_results[name] = result
      end
      infobar.finish message: "Executed tool #{bold { name }} %te %s"
      infobar.newline
    end
  end

  # The truncate_for_terminal method processes text to fit within a specified
  # number of lines.
  #
  # This method takes a text string and trims it to ensure it doesn't exceed
  # the maximum number of lines allowed for terminal display. If the text
  # exceeds the limit, only
  # the last N lines are retained where N equals the maximum lines parameter.
  #
  # @param text [ String ] the text content to be processed
  # @param max_lines [ Integer ] the maximum number of lines allowed (defaults to terminal lines)
  #
  # @return [ String ] the text truncated to fit within the specified line limit
  def truncate_for_terminal(text, max_lines: Tins::Terminal.lines)
    max_lines = max_lines.clamp(1..)
    lines = text.lines
    return text if lines.size <= max_lines
    lines[-max_lines..-1].join('')
  end

  # The ensure_assistant_response_exists method ensures that the last message
  # in the conversation is from the assistant role.
  #
  # If the last message is not from an assistant, it adds a new assistant
  # message with empty content and optionally includes thinking content if the
  # chat's think mode is enabled. It also updates the user display variable to
  # reflect the assistant's message type and styling.
  def ensure_assistant_response_exists
    if @messages&.last&.role != 'assistant'
      @messages << Message.new(
        role: 'assistant',
        content: '',
        thinking: ('' if @chat.think?)
      )
      @user = message_type(@messages.last.images) + " " +
        bold { color(111) { 'assistant:' } }
    end
  end

  # The update_last_message method appends the content of a response to the
  # last message in the conversation. It also appends thinking content to the
  # last message if thinking is enabled and thinking content is present.
  #
  # @param response [ Object ] the response object containing message content
  #   and thinking
  def update_last_message(response)
    @messages.last.content << response.message&.content
    if @chat.think_loud? and response_thinking = response.message&.thinking.full?
      @messages.last.thinking << response_thinking
    end
  end

  # The prepare_last_message method processes and formats content and thinking
  # annotations for display.
  #
  # This method prepares the final content and thinking text by applying
  # appropriate formatting based on the chat's markdown and think loud
  # settings. It handles parsing of content through Kramdown::ANSI when
  # markdown is enabled, and applies annotation
  # formatting to both content and thinking text according to the chat's
  # configuration.
  #
  # @return [Array<String, String>] an array containing the processed content
  #   and thinking text
  # @return [Array<String, nil>] an array containing the processed content and
  #   nil if thinking is disabled
  def prepare_last_message
    content, thinking = @messages.last.content, @messages.last.thinking
    if @chat.markdown.on?
      content = talk_annotate { truncate_for_terminal @chat.kramdown_ansi_parse(content) }
      if @chat.think_loud?
        thinking = think_annotate { truncate_for_terminal@chat.kramdown_ansi_parse(thinking) }
      end
    else
      content = talk_annotate { content }
      @chat.think? and thinking = think_annotate { thinking }
    end
    return content&.chomp, thinking&.chomp
  end

  # The last_message_with_user method constructs a formatted message array by
  # combining user information, newline characters, thinking annotations, and
  # content for display in the terminal output.
  #
  # @return [ Array ] an array containing the user identifier, newline
  #   character, thinking annotation (if present), and content formatted for
  #   terminal display
  def last_message_with_user
    content, thinking = prepare_last_message
    [ @user, ?\n, thinking, content ]
  end

  # The display_formatted_terminal_output method formats and outputs the
  # terminal content by processing the last message's content and thinking,
  # then prints it to the output. It handles markdown parsing and annotation
  # based on chat settings, and ensures proper formatting with clear screen and
  # move home commands. The method takes into account whether markdown and
  # thinking modes are enabled to determine how to process and display the
  # content.
  def display_formatted_terminal_output(output = nil)
    output ||= @output
    output.print(*([ clear_screen, move_home, *last_message_with_user ].compact))
  end

  # The display_output method shows the last message in the conversation.
  #
  # This method delegates to the messages object's show_last method, which
  # displays the most recent non-user message in the conversation history.
  # It is typically used to provide feedback to the user about the last
  # response from the assistant.
  # @return [ nil, String ] the pager command or nil if no paging was
  #   performed.
  def display_output
    @messages.use_pager do |output|
      if @chat.markdown.on?
        display_formatted_terminal_output(output)
      else
        output.print(*last_message_with_user)
      end
    end
  end

  # The eval_stats method processes response statistics and formats them into a
  # colored, readable string output.
  #
  # @param response [ Object ] the response object containing evaluation metrics
  #
  # @return [ String ] a formatted string with statistical information about
  #   the evaluation process including durations, counts, and rates, styled
  #   with colors and formatting
  def eval_stats(response)
    eval_duration        = response.eval_duration / 1e9
    prompt_eval_duration = response.prompt_eval_duration / 1e9
    stats_text = {
      eval_duration:        Tins::Duration.new(eval_duration),
      eval_count:           response.eval_count.to_i,
      eval_rate:            bold { "%.2f t/s" % (response.eval_count.to_i / eval_duration) } + color(111),
      prompt_eval_duration: Tins::Duration.new(prompt_eval_duration),
      prompt_eval_count:    response.prompt_eval_count.to_i,
      prompt_eval_rate:     bold { "%.2f t/s" % (response.prompt_eval_count.to_i / prompt_eval_duration) } + color(111),
      total_duration:       Tins::Duration.new(response.total_duration / 1e9),
      load_duration:        Tins::Duration.new(response.load_duration / 1e9),
    }.map { _1 * ?= } * ' '
    '📊 ' + color(111) {
      Kramdown::ANSI::Width.wrap(stats_text, percentage: 90).gsub(/(?<!\A)^/, '   ')
    }
  end

  # The output_eval_stats method outputs evaluation statistics to the specified
  # output stream.
  #
  # @param response [ Object ] the response object containing evaluation data
  def output_eval_stats(response)
    response.done or return
    @output.puts "", "", eval_stats(response)
  end

  # The debug_output method conditionally outputs the response object using jj
  # when debugging is enabled.
  #
  # @param response [ Object ] the response object to be outputted
  def debug_output(response)
    @chat.debug and jj response
  end
end
