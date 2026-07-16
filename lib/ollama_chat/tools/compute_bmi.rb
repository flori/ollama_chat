# A tool for calculating Body Mass Index (BMI) with support for different unit
# systems.
#
# This tool allows users to input weight and height in either SI (metric) or
# USCS (Imperial) units and returns the calculated BMI and the resulting
# category.
#
# @example Usage in a chat session:
#   ollama_param = { weight: 150, height: 70, units: 'USCS' }
#   ollama_chat.run('compute_bmi', ollama_param)
#   # => {"bmi": 21.51, "category": "Normal weight"}
class OllamaChat::Tools::ComputeBMI
  include OllamaChat::Tools::Concern

  # Constants for conversion
  LBS_TO_KG        = 0.453592
  INCHES_TO_METERS = 0.0254

  # @return [String] the registered name for this tool
  def self.register_name = 'compute_bmi'

  # Build the function signature for the tool.
  #
  # This method defines the parameters:
  # - weight: The weight of the person (kg for SI, lbs for USCS).
  # - height: The height of the person (m for SI, inches for USCS).
  # - units: The unit system used ('SI' or 'USCS').
  #
  # @return [Ollama::Tool] a tool definition for BMI calculation
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name: self.class.register_name,
        description: <<~EOT,
          A tool to calculate Body Mass Index (BMI) and determine weight
          category. Supports both metric (SI, the deault) and imperial (USCS)
          units. Remember to use **meters** or **feet** for height, not
          **centimeters** or **inches**.
        EOT
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            weight: {
              type: 'number',
              description: 'The weight of the person. Use kg if units is SI, or lbs if units is USCS.'
            },
            height: {
              type: 'number',
              description: 'The height of the person. Use meters if units is SI, or inches if units is USCS.'
            },
            units: {
              type: 'string',
              enum: ['SI', 'USCS'],
              description: 'The unit system being used: SI (metric) or USCS (Imperial).'
            }
          },
          required: ['weight', 'height']
        )
      )
    )
  end

  # Execute the tool logic.
  #
  # @param tool_call [OllamaChat::Tool::Call] the tool call object containing arguments
  # @param _opts [Hash] additional options
  #
  # @return [String] a JSON string containing the BMI and the category
  def execute(tool_call, **opts)
    chat   = opts[:chat]
    args   = tool_call.function.arguments
    weight = args.weight.full?(:to_f) or raise OllamaChat::ToolFunctionArgumentError, 'no weight given'
    height = args.height.full?(:to_f) or raise OllamaChat::ToolFunctionArgumentError, 'no height given'
    units  = args.units.full? || (chat.config.location.units =~ /SI/ ? 'SI' : 'USCS')

    # Convert to metric if using USCS
    if units == 'USCS'
      weight *= LBS_TO_KG
      height *= INCHES_TO_METERS
    else
      units = 'SI'
    end

    raise OllamaChat::ToolFunctionArgumentError, 'Height must be greater than zero and in kg/lbs' if height <= 0
    raise OllamaChat::ToolFunctionArgumentError, 'Weight must be less than 3m and in meter/feet' if height > 3

    bmi      = ( weight / height**2 ).round(2)
    category = calculate_category(bmi)
    message  = "This BMI is #{bmi}, which falls into the #{category} category."

    {
      bmi:,
      category:,
      units:,
      message:,
    }.to_json
  rescue => e
    chat.log(:error, e)
    { error: e.class, message: e.message }.to_json
  end

  private

  def calculate_category(bmi)
    case bmi
    when 0...18.5 then 'Underweight'
    when 18.5...25.0 then 'Normal weight'
    when 25.0...30.0 then 'Overweight'
    else 'Obese'
    end
  end

  self
end.register
