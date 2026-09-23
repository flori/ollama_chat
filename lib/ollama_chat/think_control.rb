# A module that provides thinking control functionality for OllamaChat.
#
# The ThinkControl module encapsulates methods for managing the 'think' mode
# setting in OllamaChat sessions. It handles the selection of different
# thinking modes, checking the current state, and displaying the current
# think mode status.
module OllamaChat::ThinkControl

  # The think_mode_states method returns the valid think mode states for the
  # chat's current model, with `disabled` always included.
  #
  # This is the single seam where per-model awareness enters: the lazy
  # `states:` lambda of the `think_mode` selector resolves through this
  # method, so the offered states can track the active model's capabilities
  # without the selector itself being rebuilt.
  #
  # The supported states may be:
  # * `disabled`: The thinking process is inactive.
  # * `enabled`: The thinking process is active with default settings.
  # * `low`: A minimal or subtle thinking intensity.
  # * `medium`: A balanced approach to thinking and reasoning.
  # * `high`: An intensive, detailed, or highly verbose thinking mode.
  # * `max`: The maximum thinking intensity, where supported by the model.
  #   Some models treat `high` and `max` as equivalent (e.g., Qwen3.8 maps
  #   both to its xhigh reasoning effort).
  #
  # Not every model supports every level; the concrete set returned may be a
  # subset of the above depending on the model.
  #
  # @return [ Array<String> ] the frozen list of valid think mode states
  def think_mode_states
    states =  %w[ disabled ] + (
      @model_metadata&.thinking.full?(:values) ||
      %w[ enabled low medium high max ]
    )
    states.map { normalize_think_state(_1) }.uniq.freeze
  end

  # Normalizes a raw thinking value from the Ollama `show` response into a
  # canonical state string, since different models report `thinking.values`
  # and `thinking.default` either as booleans (`[false, true]`, hybrid models)
  # or as strings (`["low", "high", "max"]`).
  #
  # @param state [Boolean, String, nil] the raw value as reported by Ollama
  # @return [ String ] the canonical state (`'enabled'`, `'disabled'`, or the
  #   value coerced to a string)
  def normalize_think_state(state)
    case state
    when true       then 'enabled'
    when false, nil then 'disabled'
    else                 state.to_s
    end
  end

  # The think method returns the current think mode selection.
  #
  # @return [ String ] the selected think mode value
  def think
    if think_mode.off?
      false
    elsif think_mode.selected == 'enabled'
      true
    else
      think_mode.selected
    end
  end

  # The think? method checks if the think mode is enabled.
  #
  # @return [TrueClass, FalseClass] true if think mode is enabled, false otherwise
  def think?
    think_mode.on?
  end

  # The think_loud? method checks if both think mode and think loud mode are
  # enabled.
  #
  # @return [ TrueClass, FalseClass ] true if think mode is enabled and think
  #   loud mode is on, false otherwise
  def think_loud?
    think? && think_loud.on?
  end
end
