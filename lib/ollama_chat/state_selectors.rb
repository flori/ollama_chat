# A module that provides state selection functionality for OllamaChat.
#
# The StateSelectors module encapsulates the StateSelector class, which manages
# configurable states with selection and display capabilities. It is used to
# handle various settings in the chat application such as document policies and
# think modes, allowing users to dynamically configure
# different aspects of the chat session behavior.
module OllamaChat::StateSelectors
  # The Common module provides shared logic and utility methods for all state
  # selection mechanisms within OllamaChat::StateSelectors.
  #
  # It encapsulates fundamental behaviors such as state validation,
  # terminal-based user interaction, and ANSI-colored output, ensuring
  # consistency across both memory-based and database-backed state selectors.
  module Common
    include Term::ANSIColor

    # The name reader returns the name of the state selector.
    #
    # @return [String] the name of the state selector
    attr_reader :name

    # The states reader returns the set of valid states for this selector.
    #
    # @return [Set<String>] the set of valid states
    attr_reader :states

    # The default reader returns the default state for this selector.
    #
    # @return [String, nil] the default state
    attr_reader :default

    # The off reader returns the list of states that are considered "off".
    #
    # @return [Array<String>] the list of "off" states
    attr_reader :off

    # The allow_empty reader returns whether the selector is allowed to be empty.
    #
    # @return [TrueClass, FalseClass] true if the selector can be empty, false otherwise
    attr_reader :allow_empty

    # The allow_empty? method checks if the switch is allowed to be empty.
    #
    # @return [ TrueClass, FalseClass ] true if the switch is allowed to be
    #   empty, false otherwise
    def allow_empty?
      !!allow_empty
    end

    # The off? method checks if the current state is in the off set.
    #
    # @return [ TrueClass, FalseClass ] true if the selected state is in the
    #   off set, false otherwise
    def off?
      off.member?(selected)
    end

    # The on? method checks if the switch is in the on state, returning true if
    # it is enabled and false if it is disabled.
    #
    # @return [ TrueClass, FalseClass ] true if the switch is on, false if it is
    #   off
    def on?
      !off?
    end

    # The choose method presents a menu to select from available states.
    #
    # This method displays the available states to the user and allows them to
    # select one. It handles the user's choice by updating the selected state
    # or exiting the chooser if the user selects '[EXIT]' or cancels the selection.
    #
    # @return [ nil ] This method does not return a value; it updates the instance
    #   variable @selected based on user input.
    def choose
      states = self.states + [ '[EXIT]' ]
      case chosen = OllamaChat::Utils::Chooser.choose(states)
      when '[EXIT]', nil
        STDOUT.puts "Exiting chooser."
      when
        self.selected = chosen
      end
    end

    # The show method outputs the current value of the state selector.
    #
    # This method displays the name of the state selector along with its
    # currently selected state in a formatted message to standard output.
    #
    # @param output [IO] the output stream to write the message to
    def show(output: STDOUT)
      output.puts "#{name} is #{bold(to_s)}."
    end

    # The to_s method returns the string representation of the selected state.
    #
    # @return [ String ] the string representation of the currently selected
    #   state
    def to_s
      selected.to_s
    end
  end

  # A state selector that manages configurable states with selection and
  # display capabilities.
  class StateSelector
    include Common

    # Initializes a new StateSelector with the given configuration.
    #
    # @param name [String] The name of the state selector for display purposes
    # @param states [Array<String>] The list of valid states this selector can have
    # @param default [String, nil] The default state to select (must be one of +states+)
    # @param off [Array<String>, nil] The list of states that should be considered "off"
    # @raise [ArgumentError] If +states+ is empty or +default+ is not in +states+
    def initialize(name:, states:, default: nil, off: nil, allow_empty: false)
      @name        = name.to_s
      @states      = Set.new(states.map(&:to_s))
      @allow_empty = allow_empty
      unless allow_empty
        states.empty? and raise ArgumentError, 'states cannot be empty'
      end
      if default
        @default  = default.to_s
        unless allow_empty?
          states.member?(@default) or raise ArgumentError,
            "default has to be one of #{states.to_a * ', '}."
        end
        @selected = @default
      else
        @selected = states.first
      end
      @off = Array(off)
    end

    # The selected reader returns the currently selected state of the switch.
    #
    # @return [Object] the currently selected state value
    attr_reader :selected

    # The selected= method sets the selected state of the switch.
    #
    # @param value [Object] the value to be converted to a string and set as
    #   the selected state
    #
    # @raise [ArgumentError] if the provided value is not one of the valid states
    def selected=(value)
      value = value.to_s
      unless allow_empty?
        states.member?(value) or raise ArgumentError,
          "value has to be one of #{states.to_a * ', '}."
      end
      @selected = value
    end

  end

  # A state selector that manages configurable states by reading from and
  # writing to a chat session's attribute.
  class DatabaseStateSelector
    include Common

    # Initializes a new DatabaseStateSelector.
    #
    # @param chat [OllamaChat::Chat] the chat instance to interact with
    # @param attribute [Symbol] the attribute name in the session to manage
    # @param name [String] the name of the state selector for display purposes
    # @param states [Array<String>] the list of valid states this selector can have
    # @param default [String, nil] the default state (retrieved from the session)
    # @param off [Array<String>, nil] the list of states that should be considered "off"
    # @param allow_empty [Boolean] whether the selector is allowed to be empty
    def initialize(chat:, attribute:, name:, states:, default: nil, off: nil, allow_empty: false)
      @chat        = chat
      @attribute   = attribute
      @name        = name
      @states      = states
      @default     = @chat.session.send(@attribute)
      @off         = off
      @allow_empty = allow_empty
    end

    # The selected reader returns the current value of the attribute from the chat session.
    #
    # @return [Object] the currently selected state value
    def selected
      @chat.session.send(@attribute)
    end

    # The selected= method sets the attribute value in the chat session.
    #
    # @param value [Object] the value to be converted to a string and set as
    #   the attribute
    #
    # @raise [ArgumentError] if the provided value is not one of the valid states
    def selected=(value)
      value = value.to_s
      unless allow_empty?
        states.member?(value) or raise ArgumentError,
          "value has to be one of #{states.to_a * ', '}."
      end
      @chat.session.update("#@attribute": value)
    end
  end

  # The document_policy reader returns the document policy selector for the chat session.
  #
  # @return [ OllamaChat::StateSelector ] the document policy selector object
  #   that manages the policy for handling document references in user text
  attr_reader :document_policy

  # The think_mode reader returns the think mode selector for the chat session.
  #
  # @return [ OllamaChat::StateSelector ] the think mode selector object
  #   that manages the thinking mode setting for the Ollama model interactions
  attr_reader :think_mode

  # Sets up state selectors for document policy and think mode based on the
  # provided configuration.
  #
  # @param config [ComplexConfig::Settings] the configuration object containing
  #   settings for document policy and think mode
  def setup_state_selectors(config)
    @document_policy = DatabaseStateSelector.new(
      chat:      self,
      attribute: :document_policy,
      name:      'Document policy',
      states:    OllamaChat::Parsing::DOCUMENT_POLICY_STATES,
      off:       OllamaChat::Parsing::DOCUMENT_POLICY_STATES[0, 1],
    )
    @think_mode = DatabaseStateSelector.new(
      chat:      self,
      attribute: :think_mode,
      name:      'Think mode',
      states:    OllamaChat::ThinkControl::THINK_MODE_STATES,
      off:       OllamaChat::ThinkControl::THINK_MODE_STATES[0, 1],
    )
    @voices = DatabaseStateSelector.new(
      chat:        self,
      attribute:   :current_voice,
      name:        'Voice',
      states:      config.voice.list,
      allow_empty: true
    )
  end
end
