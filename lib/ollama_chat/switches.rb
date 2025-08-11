module OllamaChat::Switches
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
    #
    # @return [ void ]
    def show
      STDOUT.puts @msg[value]
    end
  end

  class Switch
    # The initialize method sets up the switch instance with a name, message
    # configuration, and config object. It determines the initial boolean value
    # based on the config parameter and stores both the value and message.
    #
    # @param name [ Symbol ] the name of the switch in the config.
    # @param msg [ Hash ] a hash containing true and false messages
    # @param config [ Object ] the configuration object used to determine the switch state
    def initialize(name, msg:, config:)
      @value = [ false, true ].include?(config) ? config : !!config.send("#{name}")
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

  # The think method returns the current state of the thinking switch.
  #
  # @return [ OllamaChat::Switches::Switch ] the thinking switch instance
  attr_reader :think

  # The markdown attribute reader returns the markdown switch object.
  # The voice reader returns the voice switch instance.
  #
  # @return [ OllamaChat::Switches::Switch ] the markdown switch instance
  attr_reader :markdown

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
      :stream,
      config:,
      msg: {
        true  => "Streaming enabled.",
        false => "Streaming disabled.",
      }
    )

    @think = Switch.new(
      :think,
      config:,
      msg: {
        true  => "Thinking enabled.",
        false => "Thinking disabled.",
      }
    )

    @markdown = Switch.new(
      :markdown,
      config:,
      msg: {
        true  => "Using #{italic{'ANSI'}} markdown to output content.",
        false => "Using plaintext for outputting content.",
      }
    )

    @voice = Switch.new(
      :enabled,
      config: config.voice,
      msg: {
        true  => "Voice output enabled.",
        false => "Voice output disabled.",
      }
    )

    @embedding_enabled = Switch.new(
      :enabled,
      config: config.embedding,
      msg: {
        true  => "Embedding enabled.",
        false => "Embedding disabled.",
      }
    )

    @embedding_paused = Switch.new(
      :paused,
      config: config.embedding,
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
      :enabled,
      config: config.location,
      msg: {
        true  => "Location and localtime enabled.",
        false => "Location and localtime disabled.",
      }
    )
  end
end
