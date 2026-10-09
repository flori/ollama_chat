require 'term/ansicolor'
require 'ollama_chat/utils/value_formatter'

module OllamaChat
  # Renders the current context-window usage as colored or plain strings.
  #
  # Wraps an {OllamaChat::Chat} instance and concentrates the ANSI coloring,
  # emoji, and token-formatting logic that was previously inlined in
  # {OllamaChat::Information}. The color reflects how full the context is
  # relative to the compaction `keep_recent` / `reserve` budgets:
  #
  #   🟢 green  — below `keep_recent` (plenty of room)
  #   🟡 yellow — between `keep_recent` and `reserve` (getting tight)
  #   🔴 red    — above `reserve` (compaction imminent)
  class ContextUsage
    include Term::ANSIColor
    include OllamaChat::Utils::ValueFormatter

    EMOJI = { green: '🟢', yellow: '🟡', red: '🔴' }.freeze

    # @param chat [OllamaChat::Chat] the chat instance to read state from
    def initialize(chat)
      @chat = chat
    end

    # Colored usage string, e.g. `🟢 73.1 KT of 262.1 KT (27.9%)`.
    #
    # Every value (used tokens, context limit, percentage) is painted with the
    # threshold color; the surrounding text is bold. Returns a bold `n/a` when
    # the context length cannot be determined.
    #
    # @return [String] the ANSI-colored usage string
    def colored
      ctx = @chat.current_context_length
      return bold { 'n/a' } unless ctx

      es      = estimate
      color   = color_for(es.tokens, ctx)
      percent = percent_for(es.tokens, ctx)

      [
        EMOJI[color], ' ',
        bold { paint(color, percent) },
        ' · ',
        paint(color, es.tokens_formatted),
        ' of ',
        paint(color, format_tokens(ctx)),
      ] * ''
    end

    # Plain (uncolored) usage string, e.g. `73.1 KT of 262.1 KT (27.9%)`.
    #
    # @return [String, nil] the usage string, or nil when the context length
    #   is unknown.
    def plain
      ctx = @chat.current_context_length
      return nil unless ctx

      es = estimate
      '%s · %s of %s' % [
        percent_for(es.tokens, ctx),
        es.tokens_formatted,
        format_tokens(ctx),
      ]
    end

    # Fraction of the context window currently in use, clamped to 0.0–1.0.
    #
    # @return [Float] the fill ratio (e.g. `0.279`)
    def filled
      es = estimate
      (es.tokens.to_f / @chat.current_context_length).clamp(0..1).to_f
    end

    # Formatted percentage string, e.g. `27.9%`.
    #
    # @return [String] the percentage
    def percent
      format('%.1f%%', 100 * filled)
    end

    private

    # @return [OllamaChat::TokenEstimator::Estimate] the compacted estimate
    def estimate
      @chat.messages.compacted_estimate_tokens
    end

    # @param tokens [Integer] used tokens
    # @param ctx [Integer] context length
    # @return [String] the formatted percentage
    def percent_for(tokens, ctx)
      format('%.1f%%', 100 * (tokens.to_f / ctx).clamp(0..1))
    end

    # Resolves the threshold color for a given fill level.
    #
    # @param tokens [Integer] used tokens
    # @param ctx [Integer] context length
    # @return [Symbol] one of :green, :yellow, :red
    def color_for(tokens, ctx)
      keep_recent = @chat.compact_ratio_tokens(:keep_recent, ctx)
      reserve     = @chat.compact_ratio_tokens(:reserve, ctx)
      if tokens < keep_recent then :green
      elsif tokens <= reserve then :yellow
      else :red
      end
    end

    # Paints a string with the given threshold color.
    #
    # @param color [Symbol] one of :green, :yellow, :red
    # @param string [String] the text to colorize
    # @return [String] the ANSI-colored string
    def paint(color, string)
      case color
      when :green  then green  { string }
      when :yellow then yellow { string }
      else              red    { string }
      end
    end
  end
end
