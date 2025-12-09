# A module that provides thinking control functionality for OllamaChat.
#
# The ThinkControl module encapsulates methods for managing the 'think' mode
# setting in OllamaChat sessions. It handles the selection of different
# thinking modes, checking the current state, and displaying the current
# think mode status.
module OllamaChat::ThinkControl
  # The think method returns the current state of the think mode.
  #
  # @return [ true, false, String ] the think mode
  attr_reader :think

  # The choose_think_mode method presents a menu to select a think mode.
  #
  # This method displays available think modes to the user and sets the
  # selected mode as the current think mode for the chat session.
  def choose_think_mode
    think_modes = %w[ off on low medium high [EXIT] ]
    case chosen = OllamaChat::Utils::Chooser.choose(think_modes)
    when '[EXIT]', nil
      STDOUT.puts "Exiting chooser."
    when 'off'
      @think = false
    when 'on'
      @think = true
    when 'low', 'medium', 'high'
      @think = chosen
    end
  end

  # The think? method checks if the think mode is enabled.
  #
  # @return [ TrueClass, FalseClass ] true if think mode is enabled, false
  #   otherwise
  def think?
    !!think
  end

  # The think_mode method returns the current think mode status as a string.
  #
  # @return [ String ] returns 'enabled' if think mode is true, the think mode
  #   value if it's a string, or 'disabled' if think mode is false or nil
  def think_mode
    think == true ? 'enabled' : think || 'disabled'
  end

  # The think_show method displays the current think mode status.
  #
  # This method checks the current think mode setting and outputs a message
  # indicating whether think mode is enabled, disabled, or set to a specific
  # mode level (low, medium, high).
  def think_show
    STDOUT.puts "Think mode is #{bold(think_mode)}."
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
