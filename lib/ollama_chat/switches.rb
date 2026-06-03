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

    # Returns true if the switch is in the off state, false otherwise.
    #
    # @return [Boolean] indicating whether the switch is off
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

  # A module that intercepts switch state changes to execute registered callbacks.
  #
  # This module is designed to be prepended into switch classes. It captures
  # the value before and after a change occurs, then triggers any proc
  # associated with that specific transition in the `@callbacks` hash.
  module PerformCallbacks
    # Intercepts the set operation to trigger state-transition callbacks.
    #
    # @param a [Array] positional arguments passed to the original set method
    # @param kw [Hash] keyword arguments passed to the original set method
    # @return [Object] the result of the original set method
    def set(*a, **kw)
      before_value = value
      result = super
      perform_callbacks(before_value)
      result
    end

    # Intercepts the toggle operation to trigger state-transition callbacks.
    #
    # @param kw [Hash] keyword arguments passed to the original toggle method
    # @return [Object] the result of the original toggle method
    def toggle(**kw)
      before_value = value
      result = super
      perform_callbacks(before_value)
      result
    end

    private

    # Executes the callback proc associated with the current state transition.
    #
    # @param before_value [Boolean] the state of the switch before the change
    # @return [self] the current instance
    def perform_callbacks(before_value)
      @callbacks[[ before_value, value ]]&.(before_value, value)
      self
    end
  end

  # A switch class that manages boolean state with toggle and set functionality.
  #
  # The Switch class provides a simple way to manage boolean configuration
  # options with methods to toggle, set, and query the current state. It
  # includes messaging capabilities to provide a message when the state changes.
  #
  # @example Creating and using a switch
  #   switch = Switch.new(value: false, msg: { true => 'Enabled', false => 'Disabled' })
  #   switch.toggle  # Turns the switch on
  #   switch.value   # Returns true
  #   switch.off?    # Returns false
  #   switch.on?     # Returns true
  class Switch
    # Initializes a new Switch instance.
    #
    # @param msg [Hash{Boolean => String}] a hash containing true and false messages
    # @param value [Object] the initial state of the switch (coerced to boolean)
    # @param callbacks [Hash{[Boolean, Boolean] => Proc}] optional mapping of
    #   state transitions to callback procs. Keys are `[old_value, new_value]`.
    def initialize(msg:, value:, callbacks: {})
      @value     = !!value
      @msg       = msg
      @callbacks = callbacks.to_h
    end

    # @!attribute [r] value
    #   @return [Boolean] the current state of the switch
    attr_reader :value

    # Assigns a boolean value to the switch and optionally displays the result.
    #
    # @param value [Object] the value to be coerced to a boolean and assigned
    # @param show [Boolean] determines whether to display the status message
    # @param output [IO] the output stream to write the message to
    # @return [String, nil, Boolean] the result of the display operation or the show flag
    def set(value, show: false, output: STDOUT)
      @value = !!value
      show && self.show(output:)
    end

    # Toggles the current boolean value and optionally displays the result.
    #
    # @param show [Boolean] determines whether to show the value after toggling
    # @return [String, nil, Boolean] the result of the display operation or the show flag
    def toggle(show: true)
      @value = !@value
      show && self.show
    end

    include CheckSwitch
    prepend PerformCallbacks
  end

  # Manages boolean configuration states that are persisted in the database.
  #
  # This class acts as a wrapper around a database attribute, allowing for
  # toggling and setting of boolean values while ensuring that changes are
  # immediately saved to the associated session.
  class DatabaseSwitch
    # Initializes a new DatabaseSwitch instance.
    #
    # @param chat [OllamaChat::Chat] the chat instance providing session access
    # @param msg [Hash{Boolean => String}] the message hash containing display messages
    # @param attribute [Symbol] the database attribute name to manage
    # @param callbacks [Hash{[Boolean, Boolean] => Proc}] optional mapping of
    #   state transitions to callback procs. Keys are `[old_value, new_value]`.
    def initialize(chat:, msg:, attribute:, callbacks: {})
      @chat      = chat
      @attribute = attribute
      @msg       = msg
      @callbacks = callbacks.to_h
    end

    # Returns the current value of the attribute from the session.
    #
    # @return [Boolean] the value of the attribute
    def value
      @chat.session.send(@attribute)
    end

    # @!attribute [r] attribute
    #   @return [Symbol] the session attribute name being managed
    attr_reader :attribute

    # Updates the session attribute with the given value and optionally displays it.
    #
    # @param value [Object] the value to be coerced to a boolean and saved
    # @param show [Boolean] whether to show the updated value
    # @param output [IO] the output stream to use when showing the value
    # @return [String, nil, Boolean] the result of the display operation or the show flag
    def set(value, show: false, output: STDOUT)
      @chat.session.update("#{attribute}": !!value)
      show && self.show(output:)
    end

    # Toggles the value of a session attribute and optionally displays the new state.
    #
    # @param show [Boolean] whether to show the updated state after toggling
    # @return [String, nil, Boolean] the result of the display operation or the show flag
    def toggle(show: true)
      @chat.session.update("#{attribute}": !value)
      show && self.show
    end

    include CheckSwitch
    prepend PerformCallbacks
  end

  # Manages a boolean state based on a dynamic proc evaluation.
  #
  # The CombinedSwitch class is useful for complex conditions that depend on
  # multiple factors or dynamic values, such as combining multiple switch
  # states into a single effective state.
  #
  # @example Checking if embedding is currently performed
  #   # When embedding_enabled is true and embedding_paused is false,
  #   # the combined switch will return true
  #   combined_switch.value # => true
  class CombinedSwitch
    # Initializes a new CombinedSwitch instance.
    #
    # @param value [Proc] the proc used to determine the current state
    # @param msg [Hash{Boolean => String}] the message hash containing true and false keys
    def initialize(value:, msg:)
      @value = value
      @msg   = msg
    end

    # Returns the result of calling the stored proc.
    #
    # @return [Boolean] the result of the dynamic evaluation
    def value
      @value.()
    end

    include CheckSwitch
  end

  # @!attribute [r] stream
  #   @return [OllamaChat::Switches::DatabaseSwitch] the stream switch instance
  attr_reader :stream

  # @!attribute [r] markdown
  #   @return [OllamaChat::Switches::DatabaseSwitch] the markdown switch instance
  attr_reader :markdown

  # @!attribute [r] think_loud
  #   @return [OllamaChat::Switches::DatabaseSwitch] the think loud switch instance
  attr_reader :think_loud

  # Determines whether the `thinking` content is stripped from the message
  # payload before it is sent to the Ollama API.
  #
  # Enabling this (`true`) optimizes payload size and prevents the model from
  # being confused by its own internal reasoning traces from previous turns.
  # Disabling this (`false`) preserves the model's "chain of thought" history.
  #
  # @!attribute [r] think_strip
  #   @return [OllamaChat::Switches::DatabaseSwitch] the think strip switch instance
  attr_reader :think_strip

  # @!attribute [r] voice
  #   @return [OllamaChat::Switches::DatabaseSwitch] the voice switch instance
  attr_reader :voice

  # @!attribute [r] embedding
  #   @return [OllamaChat::Switches::CombinedSwitch] the combined embedding switch instance
  attr_reader :embedding

  # @!attribute [r] embedding_enabled
  #   @return [OllamaChat::Switches::DatabaseSwitch] the embedding enabled switch instance
  attr_reader :embedding_enabled

  # @!attribute [r] embedding_paused
  #   @return [OllamaChat::Switches::Switch] the embedding pause flag switch instance
  attr_reader :embedding_paused

  # @!attribute [r] location
  #   @return [OllamaChat::Switches::DatabaseSwitch] the location setting switch instance
  attr_reader :location

  # Controls the visibility of runtime information in the chat.
  #
  # @!attribute [r] runtime_info
  #   @return [OllamaChat::Switches::DatabaseSwitch] the runtime info visibility switch
  attr_reader :runtime_info

  # Controls tool support (off → skip all, on → honour per‑tool state).
  #
  # @!attribute [r] tools_support
  #   @return [OllamaChat::Switches::DatabaseSwitch] the tools support setting switch
  attr_reader :tools_support

  # Initializes the various switches for configuring the application's behavior.
  #
  # This method creates and configures the database and local switch objects
  # that control streaming, thinking, markdown output, voice output,
  # embedding, and location settings.
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

    reset_system_prompt = -> * {
      messages.set_system_prompt(messages.system_name)
    }

    @runtime_info = DatabaseSwitch.new(
      chat: self,
      attribute: :runtime_info_enabled,
      msg: {
        true  => "Runtime Information enabled.",
        false => "Runtime Information disabled.",
      },
      callbacks: {
        [ false, true ] => reset_system_prompt,
        [ true, false ] => reset_system_prompt,
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
