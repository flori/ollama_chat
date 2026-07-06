# A module that provides thinking control functionality for OllamaChat.
#
# The ThinkControl module encapsulates methods for managing the 'think' mode
# setting in OllamaChat sessions. It handles the selection of different
# thinking modes, checking the current state, and displaying the current
# think mode status.
module OllamaChat::ThinkControl
  # An array of strings representing the valid configuration states for the
  # thinking mode.
  #
  # These states determine the level of reasoning or verbosity applied during
  # the model's interaction.
  #
  # The supported states are:
  # * `disabled`: The thinking process is inactive.
  # * `enabled`: The thinking process is active with default settings.
  # * `low`: A minimal or subtle thinking intensity.
  # * `medium`: A balanced approach to thinking and reasoning.
  # * `high`: An intensive, detailed, or highly verbose thinking mode.
  THINK_MODE_STATES = %w[ disabled enabled low medium high ]

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
