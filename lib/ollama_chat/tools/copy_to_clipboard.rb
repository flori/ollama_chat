# A tool for copying the last assistant response to the clipboard.
#
# The executable used for the copy operation is read from the configuration
# under `copy.executable`.  The default configuration ships with
# `ctc` – a small CLI that copies stdin to the system clipboard.
#
# The tool has no parameters; it simply grabs the most recent response
# from the chat instance and streams it to the executable.
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
          Clipboard helper – Copies supplied string (or last assistant reply if
          omitted) into the OS clipboard, enabling quick pasting elsewhere. No
          output.
        EOT
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            text: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'Text to copy to the clipboard (nil = last assistant reply)'
            )
          },
          required: []
        )
      )
    )
  end

  # Execute the tool.
  #
  # @param _tool_call [OllamaChat::Tool::Call] the tool call object (unused)
  # @param opts [Hash] additional options
  # @option opts [ComplexConfig::Settings] :config the configuration object
  # @option opts [OllamaChat::Chat] :chat the chat instance
  # @return [String] JSON payload indicating success or failure
  def execute(tool_call, **opts)
    text = tool_call.function.arguments.text

    chat = opts[:chat]
    chat.perform_copy_to_clipboard(text:, content: true)

    message = if text.nil?
                "The last response has been successfully copied to the system clipboard."
              else
                "The provided text has been successfully copied to the system clipboard."
              end
    {
      success: true,
      message:,
    }.to_json
  rescue => e
    {
      error:   e.class,
      message: e.message,
    }.to_json
  end

  self
end.register
