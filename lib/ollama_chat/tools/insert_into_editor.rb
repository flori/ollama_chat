# A lightweight LLM‑driven tool that inserts a snippet directly into an open
# Vim session.
class OllamaChat::Tools::InsertIntoEditor
  include OllamaChat::Tools::Concern

  # Name of the tool used to register it with OllamaChat's tool registry.
  def self.register_name = 'insert_into_editor'

  # Returns a `OllamaChat::Tool` instance describing this function‑based tool.
  #
  # @return [OllamaChat::Tools] the configured tool definition.
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: <<~EOT,
          Insert the provided text into your editor (Vim). If no
          `text` is supplied, the tool will automatically use the last
          assistant response. This function is intended for quick code
          snippets or edits that you want to push directly into a running
          editor session without leaving OllamaChat.
        EOT
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            text: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'Text to insert into the editor (nil = last response)'
            )
          },
          required: []
        )
      )
    )
  end

  # Executes the tool by inserting text into Vim.
  #
  # @param [OllamaChat::ToolCall] tool_call The LLM-generated tool call object.
  # @option opts [OllamaChat::Chat] :chat Reference to the current chat instance.
  # @return [String] JSON‑encoded response indicating success or failure.
  def execute(tool_call, **opts)
    text = tool_call.function.arguments.text

    chat = opts[:chat]
    chat.perform_insert(text:, content: true)

    message =
      if text.nil?
        "The last response has been successfully inserted into the editor."
      else
        "The provided text has been successfully inserted into the editor."
      end

    {
      success: true,
      message:
    }.to_json
  rescue => e
    {
      error:   e.class.to_s,
      message: e.message
    }.to_json
  end

  self
end.register
