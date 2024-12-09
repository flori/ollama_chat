class OllamaChat::FollowChat
  include Ollama
  include Ollama::Handlers::Concern
  include Term::ANSIColor
  include OllamaChat::MessageType

  def initialize(messages:, markdown: false, voice: nil, output: STDOUT)
    super(output:)
    @output.sync = true
    @markdown    = markdown
    @say         = voice ? Handlers::Say.new(voice:) : NOP
    @messages    = messages
    @user        = nil
  end

  def call(response)
    OllamaChat::Chat.config.debug and jj response
    if response&.message&.role == 'assistant'
      if @messages&.last&.role != 'assistant'
        @messages << Message.new(role: 'assistant', content: '')
        @user = message_type(@messages.last.images) + " " +
          bold { color(111) { 'assistant:' } }
        @output.puts @user unless @markdown
      end
      if content = response.message&.content
        content = content.gsub(%r(<think>), "💭\n").gsub(%r(</think>), "\n💬")
      end
      @messages.last.content << content
      if @markdown and content = @messages.last.content.full?
        markdown_content = Kramdown::ANSI.parse(content)
        @output.print clear_screen, move_home, @user, ?\n, markdown_content
      else
        @output.print content
      end
      @say.call(response)
    end
    if response.done
      @output.puts "", eval_stats(response)
    end
    self
  end

  def eval_stats(response)
    eval_duration = response.eval_duration / 1e9
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
    }.map { _1 * '=' } * ' '
    '📊 ' + color(111) {
      Kramdown::ANSI::Width.wrap(stats_text, percentage: 90).gsub(/(?<!\A)^/, '   ')
    }
  end
end
