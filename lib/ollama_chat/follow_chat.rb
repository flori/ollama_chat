class OllamaChat::FollowChat
  include Ollama
  include Ollama::Handlers::Concern
  include Term::ANSIColor
  include OllamaChat::MessageType

  def initialize(chat:, messages:, voice: nil, output: STDOUT)
    super(output:)
    @chat        = chat
    @output.sync = true
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
      end
      @messages.last.content << response.message&.content
      if content = @messages.last.content.full?
        case @chat.think_mode
        when 'display'
          content = emphasize_think_block(content)
        when 'omit'
          content = omit_think_block(content)
        when 'no_delete', 'only_delete'
          content = quote_think_tags(content)
        end
        if @chat.markdown.on?
          markdown_content = Kramdown::ANSI.parse(content)
          @output.print clear_screen, move_home, @user, ?\n, markdown_content
        else
          @output.print clear_screen, move_home, @user, ?\n, content
        end
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
    }.map { _1 * ?= } * ' '
    '📊 ' + color(111) {
      Kramdown::ANSI::Width.wrap(stats_text, percentage: 90).gsub(/(?<!\A)^/, '   ')
    }
  end

  private

  def emphasize_think_block(content)
    content.gsub(%r(<think(?:ing)?>)i, "\n💭\n").gsub(%r(</think(?:ing)?>)i, "\n💬\n")
  end

  def omit_think_block(content)
    content.gsub(%r(<think(?:ing)?>.*?(</think(?:ing)?>|\z))im, '')
  end

  def quote_think_tags(content)
    if @chat.markdown.on?
      content.gsub(%r(<(think(?:ing)?)>)i, "\n\\<\\1\\>\n").gsub(%r(</(think(?:ing)?)>)i, "\n\\</\\1\\>\n")
    else
      content.gsub(%r(<(think(?:ing)?)>)i, "\n<\\1\>\n").gsub(%r(</(think(?:ing)?)>)i, "\n</\\1>\n")
    end
  end
end
