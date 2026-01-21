# A module that provides switch functionality for configuring application
# behavior.
#
# The Switches module encapsulates various toggle switches used throughout the
# OllamaChat application to control different features and settings such as
# streaming, thinking, markdown output, voice output, embedding, and location
# information. These switches allow users to dynamically enable or disable
# specific functionalities during a chat session.
#
# @example Toggling a switch on/off
#   switch = OllamaChat::Switches::Switch.new(value: false, msg: { true => 'Enabled', false => 'Disabled' })
#   switch.toggle  # Turns the switch on
#   switch.toggle  # Turns the switch off
module OllamaChat::Switches
  # A module that provides switch state checking functionality.
  #
  # The CheckSwitch module adds methods for checking the boolean state of
  # switches and displaying their current status. It's designed to be included
  # in switch classes to provide consistent behavior for querying switch states
  # and outputting status messages.
  #
  # @example Checking switch states
  #   switch = OllamaChat::Switches::Switch.new(value: true, msg: { true => 'On', false => 'Off' })
  #   switch.on?   # Returns true
  #   switch.off?  # Returns false
  module CheckSwitch
    extend Tins::Concern

    included do
      alias_method :on?, :value
    end

    # The off? method returns true if the switch is in the off state, false
    # otherwise.
    #
    # @return [ TrueClass, FalseClass ] indicating whether the switch is off
    def off?
      !on?
    end

    # The show method outputs the current value of the message to standard
    # output.
    def show
      STDOUT.puts @msg[value]
    end
  end

  # A switch class that manages boolean state with toggle and set
  # functionality.
  #
  # The Switch class provides a simple way to manage boolean configuration
  # options with methods to toggle, set, and query the current state. It
  # includes messaging capabilities to provide feedback when the state changes.
  #
  # @example Creating and using a switch
  #   switch = Switch.new(value: false, msg: { true => 'Enabled', false => 'Disabled' })
  #   switch.toggle  # Turns the switch on
  #   switch.value   # Returns true
  #   switch.off?    # Returns false
  #   switch.on?     # Returns true
  class Switch
    # The initialize method sets up the switch with a default value and
    # message.
    #
    # @param msg [ Hash ] a hash containing true and false messages
    # @param value [ Object ] the default state of the switch
    #
    # @return [ void ]
    def initialize(msg:, value:)
      @value = !!value
      @msg   = msg
    end

    # The value reader returns the current value of the attribute.
    attr_reader :value

    # The set method assigns a boolean value to the instance variable @value
    # and optionally displays it.
    #
    # @param value [ Object ] the value to be converted to a boolean and
    # assigned
    # @param show [ TrueClass, FalseClass ] determines whether to display the
    # value after setting
    def set(value, show: false)
      @value = !!value
      show && self.show
    end

    # The toggle method switches the current value of the instance variable and
    # optionally displays it.
    #
    # @param show [ TrueClass, FalseClass ] determines whether to show the
    # value after toggling
    def toggle(show: true)
      @value = !@value
      show && self.show
    end

    include CheckSwitch
  end

  # A switch class that manages a boolean state based on a proc value.
  #
  # The CombinedSwitch class provides a way to manage a boolean configuration
  # option where the state is determined by evaluating a stored proc. This is
  # useful for complex conditions that depend on multiple factors or dynamic
  # values, such as combining multiple switch states into a single effective
  # state.
  #
  # @example Checking if embedding is currently performed
  #   # When embedding_enabled is true and embedding_paused is false,
  #   # the combined switch will return true
  #   combined_switch.value # => true
  class CombinedSwitch
    # The initialize method sets up the switch with a value and message.
    #
    # @param value [ Object ] the value to be stored
    # @param msg [ Hash ] the message hash containing true and false keys
    def initialize(value:, msg:)
      @value = value
      @msg   = msg
    end

    # The value method returns the result of calling the stored proc with no
    # arguments.
    def value
      @value.()
    end

    include CheckSwitch
  end

  # The think method returns the current state of the stream switch.
  #
  # @return [ OllamaChat::Switches::Switch ] the stream switch instance
  attr_reader :stream

  # The markdown attribute reader returns the markdown switch object.
  # The voice reader returns the voice switch instance.
  #
  # @return [ OllamaChat::Switches::Switch ] the markdown switch instance
  attr_reader :markdown

  # The think_loud method returns the current state of the think loud switch.
  #
  # @return [ OllamaChat::Switches::Switch ] the think loud switch instance
  attr_reader :think_loud

  # The voice reader returns the voice switch instance.
  #
  # @return [ OllamaChat::Switches::Switch ] the voice switch instance
  attr_reader :voice

  # The embedding attribute reader returns the embedding switch object.
  #
  # @return [ OllamaChat::Switches::CombinedSwitch ] the embedding switch
  # instance
  attr_reader :embedding

  # The embedding_enabled reader returns the embedding enabled switch instance.
  #
  # @return [ OllamaChat::Switches::Switch ] the embedding enabled switch
  # instance
  attr_reader :embedding_enabled

  # The embedding_paused method returns the current state of the embedding pause flag.
  #
  # @return [ OllamaChat::Switches::Switch ] the embedding pause flag switch instance
  attr_reader :embedding_paused

  # The location method returns the current location setting.
  #
  # @return [ OllamaChat::Switches::Switch ] the location setting object
  attr_reader :location

  # The setup_switches method initializes various switches for configuring the
  # application's behavior.
  #
  # This method creates and configures multiple switch objects that control
  # different aspects of the application, such as streaming, thinking, markdown
  # output, voice output, embedding, and location settings.
  #
  # @param config [ ComplexConfig::Settings ] the configuration object
  # containing settings for the switches
  def setup_switches(config)
    @stream = Switch.new(
      value: config.stream,
      msg: {
        true  => "Streaming enabled.",
        false => "Streaming disabled.",
      }
    )

    @think_loud = Switch.new(
      value: config.think.loud,
      msg: {
        true  => "Thinking out loud, show thinking annotations.",
        false => "Thinking silently, don't show thinking annotations.",
      }
    )

    @markdown = Switch.new(
      value: config.markdown,
      msg: {
        true  => "Using #{italic{'ANSI'}} markdown to output content.",
        false => "Using plaintext for outputting content.",
      }
    )

    @voice = Switch.new(
      value: config.voice.enabled,
      msg: {
        true  => "Voice output enabled.",
        false => "Voice output disabled.",
      }
    )

    @embedding_enabled = Switch.new(
      value: config.embedding.enabled,
      msg: {
        true  => "Embedding enabled.",
        false => "Embedding disabled.",
      }
    )

    @embedding_paused = Switch.new(
      value: config.embedding.paused,
      msg: {
        true  => "Embedding paused.",
        false => "Embedding resumed.",
      }
    )

    @embedding = CombinedSwitch.new(
      value: -> { @embedding_enabled.on? && @embedding_paused.off? },
      msg: {
        true  => "Embedding is currently performed.",
        false => "Embedding is currently not performed.",
      }
    )

    @location = Switch.new(
      value: config.location.enabled,
      msg: {
        true  => "Location and localtime enabled.",
        false => "Location and localtime disabled.",
      }
    )
  end
end
