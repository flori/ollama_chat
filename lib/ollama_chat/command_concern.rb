# Provides a DSL for registering and handling commands within the
# OllamaChat application.  The concern defines a `command` class method
# that stores command metadata and a `Command` helper class that
# encapsulates execution logic.
module OllamaChat::CommandConcern
  extend Tins::Concern

  class_methods do
    # @!attribute [rw] commands
    #   @return [Hash<Symbol, Command>] A hash mapping command names to
    #   `Command` instances.
    attr_accessor :commands

    # Register a new command.
    #
    # @param name [String, Symbol] The primary name of the command.
    # @param regexp [Regexp, nil] Regular expression used to match the
    #   command invocation.  If `nil`, the command matches only when
    #   `content` is `nil`.
    # @param complete [Array, nil] Optional completion hints.  The
    #   first element is the command name(s); the rest are argument
    #   placeholders.
    # @param optional [Boolean] Whether the command is optional.
    # @param options [String, nil] A string describing command options
    #   for help output.
    # @param help [String, nil] Short help text for the command.
    # @yield [context] Block that receives a binding context for
    #   execution.  The block must be provided.
    #
    # @raise [ArgumentError] if a command with the same name already
    #   exists or if no block is given.
    def command(name:, regexp:, complete: nil, optional: false, options: nil, help: nil, &block)
      name = name.to_sym
      commands.key?(name) and
        raise ArgumentError, "command #{name} already registered!"
      commands[name] =Command.new(
        name:, regexp:, complete:, optional:, options:, help:, &block
      )
    end

    # Return an array of all available command completions.
    #
    # @return [Array<String>]
    def command_completions
      commands.each_value.map(&:completions).compact.inject(&:concat).
        map { _1.join(' ').strip.gsub(/\s+/, ' ') }.uniq.sort
    end

    # Build a formatted help table for all registered commands.
    #
    # @return [Terminal::Table] A table with columns CMD, SUBCMD, OPTS, HELP.
    def help_message
      table = Terminal::Table.new
      table.style = {
        all_separators: true,
        border:         :unicode_round,
      }
      table.headings = %w[ CMD SUBCMD OPTS HELP ]
      commands.each_value do |command|
        command.help or next
        subcommands = command.arguments[0].full? { |arg0|
          arg0.product(command.arguments[1..-1] + [ '' ]).
            map { _1.select(&:full?).join(' ') }.
            select(&:full?).map {
              [ _1, (?﹡ unless command.optional?) ].compact.join
            }.sort.join(?\n)
        }
        table << [
          "%s" % command.command_names.map { ?/ + _1 }.join(?\n),
          '%s' % subcommands,
          command.options,
          command.help,
        ]
      end
      table
    end
  end

  included do
    self.commands = {}

    delegate :commands, to: self

    delegate :command_completions, to: self

    delegate :help_message, to: self
  end

  # Represents a registered command in the OllamaChat command DSL.
  #
  # A `Command` instance stores
  #   * the command name(s) (`@complete.first`),
  #   * the matching regular expression (`@regexp`),
  #   * optional completion hints (`@complete[1..]`),
  #   * help text (`@help`), and
  #   * the block that is executed when the command matches.
  #
  # It also exposes helpers for optionality (`optional?`),
  # command names (`command_names`), arguments (`arguments`),
  # and completions (`completions`).
  #
  # The `execute_if_match?` method performs a regexp match and, if
  # successful, yields the execution context to the stored block.
  class Command
    # Create a new Command instance.
    #
    # @param name [Symbol] The command name.
    # @param regexp [Regexp, nil] Regular expression for matching.
    # @param complete [Array, nil] Completion hints.
    # @param optional [Boolean] Whether the command is optional.
    # @param options [String, nil] Options description.
    # @param help [String] Help text.
    # @yield [context] Execution block.
    #
    # @raise [ArgumentError] if no block is given.
    def initialize(name:, regexp:, complete: nil, optional: false, options: nil, help:, &block)
      block or raise ArgumentError, 'require &block'
      @name, @regexp, @optional, @options, @help, @block =
        name, regexp, optional, options, help, block
      @complete = Array(complete || name.to_s).map { Array(_1) }
    end

    # @return [Symbol] The command name.
    attr_reader :name

    # @return [String] Help text for the command.
    attr_reader :help

    # @return [String, nil] Options description.
    attr_reader :options

    # Execute the command block if the content matches the regexp.
    #
    # @param content [String, nil] The content to match against.
    # @yield [context] Context binding for execution.
    #
    # @return [Boolean] true if the command was executed, false otherwise.
    #
    # @raise [ArgumentError] if no context block is provided.
    def execute_if_match?(content, &context)
      context or raise ArgumentError, 'need &context block'
      # We invoke thee, Black Dragon of Eval, we invoke thee, O mighty force of
      # `instance_exec`, awake now from your aeonic slumber – rise from the
      # abyss!
      if @regexp.nil? && content.nil?
        context.binding.eval('self').instance_exec(&@block)
      else
        content =~ @regexp or return
        context.binding.eval('self').instance_exec(*$~.captures, &@block)
      end
    end

    # @return [Boolean] true if the command is optional.
    def optional?
      !!@optional
    end

    # @return [Array<Symbol>] Array of command names (first element of @complete).
    def command_names
      Array(@complete.first)
    end

    # @return [Array<Array>] Array of argument placeholders.
    def arguments
      Array(@complete[1..-1])
    end

    # @return [Array<Array>] All possible completions for this command.
    def completions
      result = @complete&.first&.map { ?/ + _1 }&.product(*arguments)
      if result && optional?
        result += @complete&.first.map { [ ?/ + _1 ] }
      end
      result
    end
  end
end
