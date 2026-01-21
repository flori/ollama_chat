# A module that provides state selection functionality for OllamaChat.
#
# The StateSelectors module encapsulates the StateSelector class, which manages
# configurable states with selection and display capabilities. It is used to
# handle various settings in the chat application such as document policies and
# think modes, allowing users to dynamically configure
# different aspects of the chat session behavior.
module OllamaChat::StateSelectors
  # A state selector that manages configurable states with selection and
  # display capabilities.
  class StateSelector
    include Term::ANSIColor

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
        @states.empty? and raise ArgumentError, 'states cannot be empty'
      end
      if default
        @default  = default.to_s
        unless allow_empty?
          @states.member?(@default) or raise ArgumentError,
            "default has to be one of #{@states.to_a * ', '}."
        end
        @selected = @default
      else
        @selected = @states.first
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
        @states.member?(value) or raise ArgumentError,
          "value has to be one of #{@states.to_a * ', '}."
      end
      @selected = value
    end

    # The allow_empty? method checks if the switch is allowed to be empty.
    #
    # @return [ TrueClass, FalseClass ] true if the switch is allowed to be
    #   empty, false otherwise
    def allow_empty?
      !!@allow_empty
    end

    # The off? method checks if the current state is in the off set.
    #
    # @return [ TrueClass, FalseClass ] true if the selected state is in the
    #   off set, false otherwise
    def off?
      @off.member?(@selected)
    end

    # The on? method checks if the switch is in the on state, returning true if
    # it is enabled and false if it is disabled.
    #
    # @return [ TrueClass, FalseClass ] true if the switch is on, false if it
    #   is off
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
    # variable @selected based on user input.
    def choose
      states = @states + [ '[EXIT]' ]
      case chosen = OllamaChat::Utils::Chooser.choose(states)
      when '[EXIT]', nil
        STDOUT.puts "Exiting chooser."
      when
        @selected = chosen
      end
    end

    # The show method outputs the current value of the state selector.
    #
    # This method displays the name of the state selector along with its
    # currently selected state in a formatted message to standard output.
    def show
      STDOUT.puts "#{@name} is #{bold(to_s)}."
    end

    # The to_s method returns the string representation of the selected state.
    #
    # @return [ String ] the string representation of the currently selected
    #   state
    def to_s
      @selected.to_s
    end
  end

  # Sets up state selectors for document policy and think mode based on the
  # provided configuration.
  #
  # @param config [ComplexConfig::Settings] the configuration object containing
  #   settings for document policy and think mode
  def setup_state_selectors(config)
    @document_policy = StateSelector.new(
      name: 'Document policy',
      default: config.document_policy,
      states: %w[ embedding ignoring importing summarizing ],
      off: %w[ ignoring ],
    )
    @think_mode = StateSelector.new(
      name: 'Think mode',
      default: config.think.mode,
      states: %w[ enabled disabled low medium high ],
      off: %w[ disabled ],
    )
    @voices = StateSelector.new(
      name: 'Voice',
      default: config.voice.default,
      states: config.voice.list,
      allow_empty: true
    )
  end
end
