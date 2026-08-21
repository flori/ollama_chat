# A tool for retrieving full message content from a previous conversation
# group by its short UUID suffix.
#
# When compaction summarizes older messages, the generated summary contains
# short group UUIDs (last 8 hex chars) that reference the original
# conversation turns. This tool lets the model retrieve the full content of
# any referenced group, enabling it to "zoom back in" on specific details
# that were compressed into the narrative.
#
# The search matches on the *suffix* of the `group_uuid` because the summary
# only stores the last 8 hex characters (the random portion of the UUIDv7),
# not the full 36-character string.
#
# @note The tool is read-only; it never mutates the chat or message list.
class OllamaChat::Tools::LookupGroup
  include OllamaChat::Tools::Concern

  # @return [String] the registered name for this tool
  def self.register_name = 'lookup_group'

  # Returns the tool definition for use with the Ollama API.
  #
  # @return [Ollama::Tool] a tool definition for group lookup
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
         description: <<~EOT,
           Retrieve the full messages of a previous conversation group.

           **IMPORTANT:** Provide the **last 8 hex characters** of the
           group_uuid (the random suffix), e.g. "3b874564" — NOT the
           full UUID, NOT the first 8 characters.

           The summary's tool-summaries section and narrative contain
           these short suffixes in parentheses after group references.
        EOT
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            group_uuid: Tool::Function::Parameters::Property.new(
              type: 'string',
               description: <<~EOT,
                 The **last 8 hex characters** (suffix) of the group UUID,
                 exactly as it appears in the compaction summary. e.g.
                 "3b874564".
               EOT
            )
          },
          required: %w[group_uuid]
        )
      )
    )
  end

  # Retrieves the messages belonging to the group identified by the short
  # UUID suffix and returns them as formatted JSON.
  #
  # @param tool_call [OllamaChat::Tool::Call] the tool call with arguments
  # @param opts [Hash] additional options
  # @option opts [OllamaChat::Chat] :chat the chat instance
  #
  # @return [String] a JSON string containing the group messages
  # @return [String] an error message as a JSON string if the group is
  #   not found or the argument is invalid
  def execute(tool_call, **opts)
    chat = opts[:chat]
    args = tool_call.function.arguments

    uuid = args.group_uuid.to_s.strip
    raise OllamaChat::ToolFunctionArgumentError, 'group_uuid required' if uuid.empty?

    messages = chat.messages.each_group(role: %w[user assistant tool], tool: true).find do |group|
      group.first.group_uuid.to_s.end_with?(uuid)
    end

    raise OllamaChat::OllamaChatError, "Group not found: #{uuid}" if messages.nil?

    chat.log(:info, 'Group retrieved', data: {
      tool: name, group_uuid: messages.first.group_uuid, messages: messages.size
    })

    formatted = messages.map do |msg|
      tool_tag = msg.tool_name ? " (#{msg.tool_name})" : ''
      "[#{msg.role}#{tool_tag}] #{msg.content.to_s.strip}"
    end

    {
      group_uuid: messages.first.group_uuid,
      message:    "Retrieved #{messages.size} message(s) for group #{uuid}.",
      messages:   formatted,
    }.to_json
  rescue => e
    chat.log(:error, e, data: { tool: name, group_uuid: args.group_uuid })
    { error: e.class.name, message: e.message }.to_json
  end

  self
end.register
