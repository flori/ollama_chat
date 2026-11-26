module OllamaChat
  # Provides one-shot LLM generation with context-length safety.
  #
  # Mixed into {OllamaChat::Chat}, this module owns the `generate` method
  # that all editorial LLM calls go through (compaction, session reporting,
  # prompt suggestions, character-card conversion, URL summarization, rerank).
  #
  # It guards against prompts that exceed the model's context window by
  # estimating token usage via the crude estimator, emitting a warning,
  # and truncating the prompt from the configured edge.
  module Generation
    # Sends a structured chat request to the Ollama model and returns the
    # response content.
    #
    # This method creates a minimal conversation consisting of a system
    # message and a user message, executing it as a one-shot chat
    # interaction.
    #
    # When the prompt exceeds 80% of the model's context window (after
    # accounting for the system prompt), a warning is emitted and the
    # prompt is truncated from the configured edge.
    #
    # @param system [String] the system prompt to guide the model's behavior
    #   (defaults to current raw_system_prompt)
    # @param prompt [String] the user prompt to send to the model
    # @param stream [Boolean] whether to stream the response (default: false)
    # @param think [Boolean] enable thinking mode for hybrid-thinking models
    #   (default: false)
    # @param truncate [Symbol] which edge to truncate from when the prompt
    #   exceeds the context budget: `:leading` (drop from the beginning,
    #   keep the tail) or `:trailing` (drop from the end, keep the head)
    #   (default: :leading)
    #
    # @return [String] the content of the resulting response message
    def generate(system: raw_system_prompt, prompt:, stream: false,
                 think: false, truncate: :leading)
      prompt = guard_context_length(prompt, system, truncate:)

      messages = [
        OllamaChat::Message.new(
          role:        'system',
          content:     system,
        ),

        OllamaChat::Message.new(
          role: 'user',
          content: prompt
        ),
      ]

      content = call_ollama_chat(
        model:    @model,
        messages: ,
        options:  model_options,
        stream:   ,
        think:
      )&.message&.content.to_s

      if content.empty?
        log(:warn, 'LLM generation returned empty content',
            data: { prompt:, think: })
      else
        log(:info, 'LLM generation successful',
            data: { prompt:, content:, think: })
      end

      content
    end

    private

    # Guards the prompt against exceeding the model's context window.
    #
    # Estimates total token usage (system + prompt) via the crude estimator.
    # If the prompt alone exceeds 80% of the context window minus the
    # system prompt's tokens, a warning is logged and the prompt is
    # truncated from the configured edge.
    #
    # @param prompt [String] the prompt to guard
    # @param system [String] the system prompt (for token accounting)
    # @param truncate [Symbol] `:leading` (keep tail) or `:trailing` (keep head)
    #
    # @return [String] the possibly-truncated prompt
    def guard_context_length(prompt, system, truncate:)
      ctx = current_context_length
      return prompt unless ctx

      system_tokens = TokenEstimator.estimate(system).tokens
      prompt_tokens = TokenEstimator.estimate(prompt).tokens
      budget = (ctx * 0.8).to_i - system_tokens

      return prompt if prompt_tokens <= budget

      max_chars = (budget * 3.5).to_i
      max_chars = max_chars.clamp(0, prompt.length)

      log(:warn, 'Prompt exceeds context budget, truncating',
          data: { prompt_tokens:, system_tokens:, ctx:,
                  budget:, truncate: })

      prompt = if truncate == :leading
                 "[content truncated]\n\n" + prompt[prompt.length - max_chars..]
               else
                 prompt[0, max_chars] + "\n\n[content truncated]"
               end

      feedback(
        "Prompt truncated to fit context window " \
        "(#{prompt_tokens} → " \
        "#{TokenEstimator.estimate(prompt).tokens} tokens).",
        type: :warn
      )

      prompt
    end
  end
end
