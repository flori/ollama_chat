# A tool for rolling dice using standard notation (e.g., "2d6", "d20", "3d8+5").
#
# This tool parses dice notation and returns the result of each die roll
# along with the total sum. It integrates with the Ollama tool‑calling system.
class OllamaChat::Tools::RollDice
  include OllamaChat::Tools::Concern

  # @return [String] the registered name for this tool
  def self.register_name = 'roll_dice'

  # Creates and returns a tool definition for dice rolling.
  def tool
    description = <<~EOT
      Roll dice using standard notation (e.g., "2d6", "d20", "3d8+5").

      **Supported Formats:**
      - `NdX`: Roll `N` dice with `X` sides.
      - `dX`: Roll 1 die with `X` sides.
      - `NdX+M` / `NdX-M`: Roll `N` dice with `X` sides and apply modifier `M`.

      **Example:**
      - Roll two six-sided dice: `{ "dice": "2d6" }`
      - Roll one twenty-sided die: `{ "dice": "d20" }`
      - Roll three eight-sided dice with a bonus of 5: `{ "dice": "3d8+5" }`
      EOT

    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description:,
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            dice: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'Dice notation string (e.g., "2d6", "d20", "3d8+5")'
            )
          },
          required: ['dice']
        )
      )
    )
  end

  # Executes the dice rolling operation.
  #
  # @param tool_call [Ollama::Tool::Call] the tool call object containing function details
  # @param opts [Hash] additional options
  # @option opts [ComplexConfig::Settings] :chat the chat instance
  # @return [String] the roll results as a JSON string
  def execute(tool_call, **opts)
    dice = tool_call.function.arguments.dice.to_s.strip

    # Parse the dice notation
    match = dice.match(/^(\d*)d(\d+)([+-]\d+)?$/i)

    match or raise OllamaChat::ToolFunctionArgumentError,
      'Invalid dice notation %s. Use format like "2d6", "d20", or "3d8+5".' % dice.inspect

    count    = match[1].to_i.nonzero? || 1
    sides    = match[2].to_i
    modifier = match[3].to_i
    min      = count + modifier
    max      = count * sides + modifier

    # Generate rolls
    rolls = count.times.map { rand(1..sides) }
    total = rolls.sum + modifier

    message = "Dice roll was: %s = (%s)" % [ dice, rolls * ' + ' ]
    if modifier > 0
      message << " + %u" % modifier
    elsif modifier < 0
      message << " - %u" % -modifier
    end
    message << " = %u" % total

    {
      dice:,
      rolls:,
      modifier:,
      total:,
      min:,
      max:,
      message:
    }.to_json
  rescue => e
    { error: e.class, message: e.message }.to_json
  end

  self
end.register
