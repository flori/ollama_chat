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
#   follow_chat.call(response)
class OllamaChat::FollowChat
  include Ollama
  include Ollama::Handlers::Concern
  include Term::ANSIColor
  include OllamaChat::MessageFormat

  # Initializes a new instance of OllamaChat::FollowChat.
  #
  # @param [OllamaChat::Chat] chat The chat object, which represents the
  # conversation context.
  # @param [#to_a] messages A collection of message objects, representing the
  # conversation history.
  # @param [String] voice (optional) to speek with if any.
  # @param [IO] output (optional) The output stream where terminal output
  # should be printed. Defaults to STDOUT.
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
  # the conversation.
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
  # server.
  #
  # @return [OllamaChat::FollowChat] The current instance for method chaining.
  def call(response)
    debug_output(response)

    if response&.message&.role == 'assistant'
      ensure_assistant_response_exists
      update_last_message(response)
      display_formatted_terminal_output
      @say.call(response)
    end

    output_eval_stats(response)

    self
  end

  private

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
  # and thinking
  def update_last_message(response)
    @messages.last.content << response.message&.content
    if @chat.think_loud? and response_thinking = response.message&.thinking.full?
      @messages.last.thinking << response_thinking
    end
  end

  # The display_formatted_terminal_output method formats and outputs the
  # terminal content by processing the last message's content and thinking,
  # then prints it to the output. It handles markdown parsing and annotation
  # based on chat settings, and ensures proper formatting with clear screen and
  # move home commands. The method takes into account whether markdown and
  # thinking modes are enabled to determine how to process and display the
  # content.
  def display_formatted_terminal_output
    content, thinking = @messages.last.content, @messages.last.thinking
    if @chat.markdown.on?
      content = talk_annotate { @chat.kramdown_ansi_parse(content) }
      if @chat.think_loud?
        thinking = think_annotate { @chat.kramdown_ansi_parse(thinking) }
      end
    else
      content = talk_annotate { content }
      @chat.think? and thinking = think_annotate { thinking }
    end
    @output.print(*([
      clear_screen, move_home, @user, ?\n, thinking, content
    ].compact))
  end

  # The eval_stats method processes response statistics and formats them into a
  # colored, readable string output.
  #
  # @param response [ Object ] the response object containing evaluation metrics
  #
  # @return [ String ] a formatted string with statistical information about
  # the evaluation process including durations, counts, and rates, styled with
  # colors and formatting
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
    @output.puts "", eval_stats(response)
  end

  # The debug_output method conditionally outputs the response object using jj
  # when debugging is enabled.
  #
  # @param response [ Object ] the response object to be outputted
  def debug_output(response)
    @chat.debug and jj response
  end
end
