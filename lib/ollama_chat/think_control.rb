# A module that provides thinking control functionality for OllamaChat.
#
# The ThinkControl module encapsulates methods for managing the 'think' mode
# setting in OllamaChat sessions. It handles the selection of different
# thinking modes, checking the current state, and displaying the current
# think mode status.
module OllamaChat::ThinkControl
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
