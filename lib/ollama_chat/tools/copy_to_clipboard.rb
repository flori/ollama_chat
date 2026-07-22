# A tool for copying a text to the clipboard.
#
# The executable used for the copy operation is read from the configuration
# under `copy.executable`.  The default configuration ships with
# `ctc` – a small CLI that copies stdin to the system clipboard.
class OllamaChat::Tools::CopyToClipboard
  include OllamaChat::Tools::Concern

  # @return [String] the registered name for this tool
  def self.register_name = 'copy_to_clipboard'

  # Build the OpenAI function schema for the tool.
  # No parameters are required.
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: <<~EOT,
          Clipboard helper – Copies supplied string into the OS clipboard,
          enabling quick pasting elsewhere. No output.
        EOT
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            text: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'Text to copy to the clipboard'
            ),
            edit: Tool::Function::Parameters::Property.new(
              type: 'boolean',
              description: 'True if the copied text should be edited by the user, (default: false)'
            )
          },
          required: %w[ text ]
        )
      )
    )
  end

  # Execute the tool.
  #
  # @param _tool_call [OllamaChat::Tool::Call] the tool call object (unused)
  # @param opts [Hash] additional options
  # @option opts [OllamaChat::Chat] :chat the chat instance
  # @return [String] JSON payload indicating success or failure
  def execute(tool_call, **opts)
    chat = opts[:chat]
    args = tool_call.function.arguments
    edit = !!args.edit
    text = args.text.full? or raise OllamaChat::ToolFunctionArgumentError, 'no text given'

    chat.perform_copy_to_clipboard(text:, content: true, edit:)

    message = "The provided text has been successfully copied to the system clipboard."

    {
      success:  true,
      message: ,
    }.to_json
  rescue => e
    chat.log(:error, e, data: { tool: 'copy_to_clipboard' })
    {
      error:   e.class,
      message: e.message,
    }.to_json
  end

  self
end.register
