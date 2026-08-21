# Provides compaction support for chat sessions. Mixed into `Chat`.
#
# Supplies configuration resolvers that derive concrete token budgets
# from the `compaction:` config block (ratios of `num_ctx` with absolute
# floors), the LLM-based summarization pipeline
# (+summarize_for_compaction+), and the +tool_summary_line+ resolver
# for per-tool summary templates.
#
# @see OllamaChat::OllamaChatConfig::DefaultConfig for the `compaction:`
#   block structure (`reserve`, `keep_recent`, `summary`).
module OllamaChat::Compaction
  class << self
    # Generates a one-line summary for a tool call result.
    #
    # Looks up the registered tool class and delegates to its
    # `summary_template(result:)` class method. Falls back to a generic
    # sentence if the tool is not registered or the template raises.
    #
    # @param tool_name [String] the registered name, e.g. `'read_file'`.
    # @param result [String] the raw JSON result string from `execute`.
    # @return [String] a short natural-language description of the call.
    def tool_summary_line(tool_name, result)
      default_summary = "was called."
      klass           = OllamaChat::Tools.registered[tool_name.to_s]&.class
      klass&.summary_template(result:) || default_summary
    rescue StandardError
      default_summary
    end
  end

  # Value object carrying the outcome of a successful +compact!+ call.
  #
  # @!attribute [r] context_before
  #   @return [String] formatted context usage before compaction
  # @!attribute [r] context_after
  #   @return [String] formatted context usage after compaction
  # @!attribute [r] candidates
  #   @return [Integer] number of messages that were summarized
  # @!attribute [r] candidate_size
  #   @return [String] formatted size of the candidate block
  # @!attribute [r] summary_size
  #   @return [String] formatted size of the generated summary
  # @!attribute [r] stored_total
  #   @return [String] formatted full conversation length
  Result = Data.define(
    :context_before, :context_after,
    :candidates, :candidate_size,
    :summary_size, :stored_total
  )

  # Generates a context summary for the given messages via LLM.
  #
  # Serializes non-system messages into a structured prompt, calls the
  # model via +generate+, and assembles the final summary with
  # deterministic tool-call entries stored out-of-band.
  #
  # @param messages [Array<OllamaChat::Message>] the messages to summarize.
  # @param previous_summary [OllamaChat::Message, nil] the previous summary
  #   message for iterative re-compaction.
  # @return [Array(String, Array<Hash>)] the assembled content and the
  #   merged tool-call entries array.
  def summarize_for_compaction(messages:, previous_summary: nil)
    groups       = serialize_groups(messages)
    tool_entries = build_tool_entries(messages)

    es = OllamaChat::TokenEstimator.estimate(groups)
    log(:info, "Compaction: #{messages.size} messages, " \
      "#{es.tokens_formatted} (#{es.bytes_formatted}) groups")

    narrative_prev = ''
    old_tool_calls = []
    if previous_summary
      narrative_prev = extract_narrative(previous_summary.content)
      old_tool_calls = extract_old_tool_calls(previous_summary)
    end

    narrative = call_summarizer(groups:, previous_summary: narrative_prev)
    assemble_summary(narrative, tool_entries, old_tool_calls)
  end

  # Resolves the effective token budget for a concern given a context size.
  #
  # Computes `max(ratio * tokens, min_tokens).floor`, so the floor acts as
  # a guaranteed minimum even for very small context windows.
  #
  # @param name [Symbol] the concern name, e.g. `:reserve`, `:keep_recent`,
  #   or `:summary`.
  # @param tokens [Integer] the context window size (`num_ctx`) to derive
  #   the budget from.
  # @return [Integer] the resolved token budget.
  def compact_ratio_tokens(name, tokens)
    [
      compact_ratio(name).to_f * tokens,
      compact_min_tokens(name).to_f,
    ].max.floor
  end

  # Attempts compaction, prompting the user to retry on failure.
  #
  # +compact!+ is idempotent on failure: the LLM call (and thus any
  # +CompactionError+) happens before the message list is mutated, so a
  # retry always starts from a clean state.
  #
  # @return [Boolean] true if compaction succeeded, false if the user
  #   declined to retry.
  def compact_with_retry
    result   = messages.compact!
    session_sync
    if result
      report_compaction(result)
    else
      STDOUT.puts('Nothing to compact.')
    end
    return true
  rescue OllamaChat::CompactionError => e
    STDERR.puts "⚠️  Compaction failed: #{e.message}"
    log(:error, "Compaction failed", data: {
      model: @model,
      ctx:   current_context_length,
      size:  messages.size,
    })
    retry if confirm?(
      prompt: '🔔 Retry compaction? (y/n) ',
      yes: /\Ay/i
    )
    false
  end

  private

  # Serializes non-system messages into a readable block for the prompt.
  #
  # @param messages [Array<OllamaChat::Message>] the messages to serialize.
  # @return [String] a formatted block of message lines.
  def serialize_groups(messages)
    messages
      .reject { _1.role == 'system' }
      .map { |m| format_summary_line(m) }
      .join("\n")
  end

  # Formats a single message as a summary line.
  #
  # @param msg [OllamaChat::Message] the message to format.
  # @return [String] a single line describing the message.
  def format_summary_line(msg)
    tool_name = msg.tool_name.full?
    parts  = +"[#{msg.role}]"
    parts << " (#{tool_name})" if tool_name
    parts << " (g:#{msg.group_uuid.to_s[-8..]})" if msg.group_uuid
    if tool_name
      line = OllamaChat::Compaction.tool_summary_line(tool_name, msg.content.to_s)
      parts << " #{line}"
    elsif msg.content.present?
      parts << " #{msg.content.to_s.strip}"
    end
    parts
  end

  # Builds the deterministic tool-call entries from tool result messages.
  #
  # @param messages [Array<OllamaChat::Message>] the messages to scan.
  # @return [Array<Hash>] tool-call entry hashes, empty if no tool results.
  def build_tool_entries(messages)
    messages.filter_map do |msg|
      next unless tool_name = msg.tool_name.full?
      next if tool_name == 'runtime_information'
      uuid = msg.group_uuid.to_s[-8..]
      summary = OllamaChat::Compaction.tool_summary_line(
        tool_name, msg.content.to_s
      )
      time = msg.group_time&.strftime('%Y-%m-%d %H:%M')
      {
        'type'    => 'tool',
        'name'    => tool_name,
        'summary' => summary,
        'uuid'    => uuid,
        'time'    => time,
      }
    end
  end

  # Calls the LLM to generate the narrative portion of the summary.
  #
  # @param groups [String] the serialized groups block.
  # @param previous_summary [String, nil] the prior summary for iteration.
  # @return [String] the LLM-generated narrative text.
  def call_summarizer(groups:, previous_summary:)
    previous = previous_summary.to_s

    prompt = prompt(:summarize, context: 'compaction').to_s % {
      previous:, groups:
    }
    system = prompt(:system, context: 'compaction').to_s

    es = OllamaChat::TokenEstimator.estimate(prompt)
    log(:info, "Compaction: sending prompt " \
      "#{es.tokens_formatted} (#{es.bytes_formatted}) to #{@model}")

    response = Infobar.busy(
      label: 'Compacting context…',
      frames: :braille7,
      output: STDOUT,
    ) do
      generate(system:, prompt:, think: true).strip
    end

    if response.empty?
      log(:error, 'Compaction: LLM returned empty response')
      raise OllamaChat::CompactionError,
            'Summarization failed: model returned empty response'
    end

    res_es = OllamaChat::TokenEstimator.estimate(response)
    log(:info, "Compaction: got response " \
      "#{res_es.tokens_formatted} (#{res_es.bytes_formatted})")

    response
  end

  # Assembles the final summary content and merged tool entries.
  #
  # @param narrative [String] the LLM-generated narrative.
  # @param tool_entries [Array<Hash>] new tool-call entries from this pass.
  # @param old_tool_entries [Array<Hash>] entries carried over from a
  #   prior compaction.
  # @return [Array(String, Array<Hash>)] the content string and the
  #   merged entries array.
  def assemble_summary(narrative, tool_entries, old_tool_entries = [])
    all_tools    = old_tool_entries + tool_entries
    tool_section = all_tools.map(&:to_json) * ?\n

    template = prompt(:assemble, context: 'compaction').to_s
    content  = template % { narrative:, tool_section: }

    [content, all_tools]
  end

  # Extracts the narrative portion from a summary message's content.
  #
  # @param content [String, nil] the summary content.
  # @return [String] the narrative text.
  def extract_narrative(content)
    content.to_s.sub(/\ntool_calls:\n.*\z/m, '').strip
  end

  # Returns the tool-call entries from a previous summary message.
  #
  # @param summary_msg [OllamaChat::Message] the previous summary message.
  # @return [Array<Hash>] the tool-call entries, empty if none.
  def extract_old_tool_calls(summary_msg)
    summary_msg.tool_calls || []
  end

  # Returns the absolute minimum token floor for a given concern.
  #
  # @param name [Symbol] the concern name, e.g. `:reserve`, `:keep_recent`,
  #   or `:summary`.
  # @return [Integer] the configured `min_tokens` floor.
  def compact_min_tokens(name)
    config.compaction.attribute_get!(name).min_tokens
  end

  # Returns the fractional ratio (portion of `num_ctx`) for a given concern.
  #
  # @param name [Symbol] the concern name, e.g. `:reserve`, `:keep_recent`,
  #   or `:summary`.
  # @return [Float] the configured `ratio` value.
  def compact_ratio(name)
    config.compaction.attribute_get!(name).ratio
  end

  # Displays a compact compaction report to +STDOUT+ after the
  # +Infobar.busy+ spinner has finished.
  #
  # Replaces the former bare "Conversation compacted." line with
  # before/after context metrics, candidate volume, and summary size.
  #
  # @param result [Result] the compaction result from +compact!+.
  def report_compaction(result)
    STDOUT.puts(<<~EOT)
      ✅ Conversation compacted.
         Summarized:   #{result.candidates} messages (#{result.candidate_size})
         Summary:      #{result.summary_size}
         Context:      #{result.context_before} → #{result.context_after}
         Stored total: #{result.stored_total}
    EOT
  end
end
