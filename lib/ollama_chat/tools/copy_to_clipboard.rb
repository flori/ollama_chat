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

  # Register the tool name for the OllamaChat runtime.
  def self.register_name = 'copy_to_clipboard'

  # Build the OpenAI function schema for the tool.
  # No parameters are required.
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: 'Copy the last assistant response to the system clipboard',
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {},
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
  def execute(_tool_call, **opts)
    chat = opts[:chat]
    chat.perform_copy_to_clipboard(content: true)
    {
      success: true,
      message: "The last response has been successfully copied to the system clipboard."
    }.to_json
  rescue => e
    {
      error: e.class,
      message: e.message
    }.to_json
  end

  self
end.register
