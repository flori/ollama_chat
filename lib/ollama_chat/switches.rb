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

    # Displays the message associated with the current switch state.
    #
    # @param output [IO] the output stream to write the message to
    def show(output: STDOUT)
      output.puts @msg[value]
    end
  end

  # A switch class that manages boolean state with toggle and set
  # functionality.
  #
  # The Switch class provides a simple way to manage boolean configuration
  # options with methods to toggle, set, and query the current state. It
  # includes messaging capabilities to provide message when the state changes.
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
    #   assigned
    # @param show [ TrueClass, FalseClass ] determines whether to display the
    #   value after setting
    # @param output [IO] the output stream to write the message to
    def set(value, show: false, output: STDOUT)
      @value = !!value
      show && self.show(output:)
    end

    # The toggle method switches the current value of the instance variable and
    # optionally displays it.
    #
    # @param show [ TrueClass, FalseClass ] determines whether to show the
    #   value after toggling
    def toggle(show: true)
      @value = !@value
      show && self.show
    end

    include CheckSwitch
  end

  # The DatabaseSwitch class provides a mechanism for managing boolean
  # configuration states that are persisted in the database.
  #
  # This class acts as a wrapper around a database attribute, allowing for
  # toggling and setting of boolean values while ensuring that changes are
  # immediately saved to the associated session.
  #
  # It is used in the application's switches to manage settings like streaming,
  # thinking modes, markdown output, and other session-specific toggles.
  class DatabaseSwitch
    # Initializes a new DatabaseSwitch instance.
    #
    # @param chat [OllamaChat::Chat] the chat instance
    # @param msg [Hash] the message hash containing display messages
    # @param attribute [Symbol] the attribute name to switch
    def initialize(chat:, msg:, attribute:)
      @chat      = chat
      @attribute = attribute
      @msg      = msg
    end

    # The value method returns the current value of the attribute from the
    # session.
    #
    # @return [Object] the value of the attribute
    def value
      @chat.session.send(@attribute)
    end

    # The attribute method returns the value of the attribute instance
    # variable.
    #
    # @return [Object] the value of the attribute instance variable
    attr_reader :attribute

    # The set method updates the session attribute with the given value.
    #
    # @param value [Object] the value to set
    # @param show [TrueClass, FalseClass] whether to show the updated value
    # @param output [IO] the output stream to use when showing the value
    def set(value, show: false, output: STDOUT)
      @chat.session.update("#{attribute}": !!value)
      show && self.show(output:)
    end

    # The toggle method switches the value of a session attribute and
    # optionally displays the new state.
    #
    # @param show [ TrueClass, FalseClass ] whether to show the updated state
    #   after toggling
    def toggle(show: true)
      @chat.session.update("#{attribute}": !value)
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

  # The switch that determines whether the `thinking` content is stripped from
  # the message payload before it is sent to the Ollama API.
  #
  # Enabling this (`true`) helps optimize the payload size and prevents
  # the model from being potentially confused by its own internal
  # reasoning traces from previous turns.
  #
  # Disabling this (`false`) preserves the model's "chain of thought"
  # history, allowing it to reference its previous logic.
  #
  # @return [ OllamaChat::Switches::Switch ] the think strip switch instance
  attr_reader :think_strip

  # The voice reader returns the voice switch instance.
  #
  # @return [ OllamaChat::Switches::Switch ] the voice switch instance
  attr_reader :voice

  # The embedding attribute reader returns the embedding switch object.
  #
  # @return [ OllamaChat::Switches::CombinedSwitch ] the embedding switch
  #   instance
  attr_reader :embedding

  # The embedding_enabled reader returns the embedding enabled switch instance.
  #
  # @return [ OllamaChat::Switches::Switch ] the embedding enabled switch
  #   instance
  attr_reader :embedding_enabled

  # The embedding_paused method returns the current state of the embedding pause flag.
  #
  # @return [ OllamaChat::Switches::Switch ] the embedding pause flag switch instance
  attr_reader :embedding_paused

  # The location method returns the current location setting.
  #
  # @return [ OllamaChat::Switches::Switch ] the location setting object
  attr_reader :location

  # Provides access to the runtime_info switch controlling the visibility of
  # runtime information in the chat
  #
  # @attr_reader [ Switches::Switch ] a Switch instance that manages runtime
  #   info visibility
  attr_reader :runtime_info

  # Switch tools support on/off (off → skip all, on → honour per‑tool state)
  #
  # @return [OllamaChat::Switch] the tools_support setting object
  attr_reader :tools_support

  # The setup_switches method initializes various switches for configuring the
  # application's behavior.
  #
  # This method creates and configures multiple switch objects that control
  # different aspects of the application, such as streaming, thinking, markdown
  # output, voice output, embedding, and location settings.
  def setup_switches
    @stream = DatabaseSwitch.new(
      chat: self,
      attribute: :stream_enabled,
      msg: {
        true  => "Streaming enabled.",
        false => "Streaming disabled.",
      }
    )

    @think_loud = DatabaseSwitch.new(
      chat: self,
      attribute: :think_loud_enabled,
      msg: {
        true  => "Thinking out loud, show thinking annotations.",
        false => "Thinking silently, don't show thinking annotations.",
      }
    )

    @think_strip = DatabaseSwitch.new(
      chat: self,
      attribute: :think_strip_enabled,
      msg: {
        true  => "Stripping thinking content is enabled.",
        false => "Stripping thinking content is disabled.",
      }
    )

    @markdown = DatabaseSwitch.new(
      chat: self,
      attribute: :markdown_enabled,
      msg: {
        true  => "Using #{italic{'ANSI'}} markdown to output content.",
        false => "Using plaintext for outputting content.",
      }
    )

    @voice = DatabaseSwitch.new(
      chat: self,
      attribute: :voice_enabled,
      msg: {
        true  => "Voice output enabled.",
        false => "Voice output disabled.",
      }
    )

    @embedding_enabled = DatabaseSwitch.new(
      chat: self,
      attribute: :embedding_enabled,
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

    @location = DatabaseSwitch.new(
      chat: self,
      attribute: :location_enabled,
      msg: {
        true  => "Location enabled.",
        false => "Location disabled.",
      }
    )

    @runtime_info = DatabaseSwitch.new(
      chat: self,
      attribute: :runtime_info_enabled,
      msg: {
        true  => "Runtime Information enabled.",
        false => "Runtime Information disabled.",
      }
    )

    @tools_support = DatabaseSwitch.new(
      chat:      self,
      attribute: :tools_enabled,
      msg: {
        true  => "Tools support enabled.",
        false => "Tools support disabled.",
      }
    )
  end
end
