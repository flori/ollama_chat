module OllamaChat::Switches
  module CheckSwitch
    extend Tins::Concern

    included do
      alias_method :on?, :value
    end

    def off?
      !on?
    end

    def show
      STDOUT.puts @msg[value]
    end
  end

  class Switch
    def initialize(name, msg:, config:)
      @value = [ false, true ].include?(config) ? config : !!config.send("#{name}?")
      @msg   = msg
    end

    attr_reader :value

    def set(value, show: false)
      @value = !!value
      show && self.show
    end

    def toggle(show: true)
      @value = !@value
      show && self.show
    end

    include CheckSwitch
  end

  class CombinedSwitch
    def initialize(value:, msg:)
      @value = value
      @msg   = msg
    end

    def value
      @value.()
    end

    include CheckSwitch
  end

  attr_reader :markdown

  attr_reader :location

  def setup_switches(config)
    @markdown = Switch.new(
      :markdown,
      config:,
      msg: {
        true  => "Using #{italic{'ANSI'}} markdown to output content.",
        false => "Using plaintext for outputting content.",
      }
    )

    @stream = Switch.new(
      :stream,
      config:,
      msg: {
        true  => "Streaming enabled.",
        false => "Streaming disabled.",
      }
    )

    @voice = Switch.new(
      :stream,
      config: config.voice,
      msg: {
        true  => "Voice output enabled.",
        false => "Voice output disabled.",
      }
    )

    @embedding_enabled = Switch.new(
      :embedding_enabled,
      config:,
      msg: {
        true  => "Embedding enabled.",
        false => "Embedding disabled.",
      }
    )

    @embedding_paused = Switch.new(
      :embedding_paused,
      config:,
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
      :location,
      config: config.location.enabled,
      msg: {
        true  => "Location and localtime enabled.",
        false => "Location and localtime disabled.",
      }
    )
  end
end
