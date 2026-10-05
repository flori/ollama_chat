# A lightweight LLM‑driven tool that pastes a snippet directly into an open
# Vim session.
class OllamaChat::Tools::PasteIntoEditor
  include OllamaChat::Tools::Concern

  # @return [String] the registered name for this tool
  def self.register_name = 'paste_into_editor'

  # Returns a `OllamaChat::Tool` instance describing this function‑based tool.
  #
  # @return [OllamaChat::Tools] the configured tool definition.
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: <<~EOT,
          Editor helper – Pastes a text into the editor, no file or line is required.
          Only call this tool
          1. if the user requested it explicitly and
          2. only once not multiple times.
        EOT
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            text: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'Text to paste into the editor'
            )
          },
          required: %w[ text ]
        )
      )
    )
  end

  # Executes the tool by pasting text into Vim.
  #
  # @param [OllamaChat::ToolCall] tool_call The LLM-generated tool call object.
  # @return [String] JSON‑encoded response indicating success or failure.
  def execute(tool_call, **opts)
    text = tool_call.function.arguments.text

    chat.perform_insert(text:, content: true)

    message = "The provided text has been successfully pasted into the editor."

    {
      success:  true,
      message: ,
    }.to_json
  rescue => e
    chat.log(:error, e, data: { tool: name })
    {
      error:   e.class.to_s,
      message: e.message,
    }.to_json
  end

  self
end.register
