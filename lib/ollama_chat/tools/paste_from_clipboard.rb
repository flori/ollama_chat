# A tool for pasting content from the clipboard.
#
# This tool allows the chat client to retrieve content from the system
# clipboard and make it available for use in the chat session.
# It integrates with the Ollama tool calling system to provide
# clipboard reading capabilities to the language model.
class OllamaChat::Tools::PasteFromClipboard
  include OllamaChat::Tools::Concern

  # Register the tool name for the OllamaChat runtime.
  def self.register_name = 'paste_from_clipboard'

  # Build the OpenAI function schema for the tool.
  # No parameters are required.
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: <<~EOT,
          Clipboard reader – Inserts whatever is currently in your OS clipboard
          as a new message to the assistant, enabling quick transfer of
          external snippets.
        EOT
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

    # Use the chat instance's clipboard paste functionality
    content = chat.perform_paste_from_clipboard

    {
      success: true,
      message: "Content pasted from clipboard",
      content:
    }.to_json
  rescue => e
    {
      error:   e.class,
      message: e.message,
    }.to_json
  end

  self
end.register
