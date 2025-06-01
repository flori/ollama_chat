class OllamaChat::FollowChat
  include Ollama
  include Ollama::Handlers::Concern
  include Term::ANSIColor
  include OllamaChat::MessageFormat

  def initialize(chat:, messages:, voice: nil, output: STDOUT)
    super(output:)
    @chat        = chat
    @output.sync = true
    @say         = voice ? Handlers::Say.new(voice:) : NOP
    @messages    = messages
    @user        = nil
  end

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

  def ensure_assistant_response_exists
    if @messages&.last&.role != 'assistant'
      @messages << Message.new(
        role: 'assistant',
        content: '',
        thinking: ('' if @chat.think.on?)
      )
      @user = message_type(@messages.last.images) + " " +
        bold { color(111) { 'assistant:' } }
    end
  end

  def update_last_message(response)
    @messages.last.content << response.message&.content
    if @chat.think.on? and response_thinking = response.message&.thinking.full?
      @messages.last.thinking << response_thinking
    end
  end

  def display_formatted_terminal_output
    content, thinking = @messages.last.content, @messages.last.thinking
    if @chat.markdown.on?
      content = talk_annotate { Kramdown::ANSI.parse(content) }
      if @chat.think.on?
        thinking = think_annotate { Kramdown::ANSI.parse(thinking) }
      end
    else
      content = talk_annotate { content }
      @chat.think.on? and thinking = think_annotate { @messages.last.thinking.full? }
    end
    @output.print(*([
      clear_screen, move_home, @user, ?\n, thinking, content
    ].compact))
  end

  def eval_stats(response)
    eval_duration        = response.eval_duration / 1e9
    prompt_eval_duration = response.prompt_eval_duration / 1e9
    stats_text = {
      eval_duration:        Tins::Duration.new(eval_duration),
      eval_count:           response.eval_count.to_i,
      eval_rate:            bold { "%.2f c/s" % (response.eval_count.to_i / eval_duration) } + color(111),
      prompt_eval_duration: Tins::Duration.new(prompt_eval_duration),
      prompt_eval_count:    response.prompt_eval_count.to_i,
      prompt_eval_rate:     bold { "%.2f c/s" % (response.prompt_eval_count.to_i / prompt_eval_duration) } + color(111),
      total_duration:       Tins::Duration.new(response.total_duration / 1e9),
      load_duration:        Tins::Duration.new(response.load_duration / 1e9),
    }.map { _1 * ?= } * ' '
    '📊 ' + color(111) {
      Kramdown::ANSI::Width.wrap(stats_text, percentage: 90).gsub(/(?<!\A)^/, '   ')
    }
  end

  def output_eval_stats(response)
    response.done or return
    @output.puts "", eval_stats(response)
  end

  def debug_output(response)
    OllamaChat::Chat.config.debug and jj response
  end
end
