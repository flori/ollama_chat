# A tool for removing a persistent memory entry from a per-persona
# documentrix collection.
#
# This class implements a tool that deletes the single record tagged with a
# specific timestamp from the `memory-<persona_name>` collection. It is the
# surgical inverse of `memorize`: one tag points at one memory, and clearing
# that tag forgets exactly that memory and nothing else.
#
# @example Forgetting a memory:
#   forget(timestamp: '2026-09-29T23:12:57+02:00',
#          persona_name: 'miyu_pairing')
class OllamaChat::Tools::Forget
  include OllamaChat::Tools::Concern

  # @return [String] the registered name for this tool
  def self.register_name = 'forget'

  # Build the function signature for the tool.
  #
  # @return [Ollama::Tool] a tool definition for forgetting a memory entry
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: <<~EOT,
          Remove a persistent memory entry from the persona's memory
          collection. Provide the `timestamp` tag returned by a prior
          `search_knowledge` call to forget that specific entry. The
          surgical inverse of `memorize`.
        EOT
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            timestamp: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: <<~EOT,
                The ISO 8601 timestamp tag of the memory to forget,
                exactly as it appeared in a `search_knowledge` result's
                tags. E.g. '2026-09-29T23:12:57+02:00'.
              EOT
            ),
            persona_name: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: <<~EOT,
                The persona name (e.g. 'sarah', 'miyu_pairing').
                The memory is removed from the collection
                'memory-<persona_name>'.
              EOT
            ),
          },
          required: %w[timestamp persona_name]
        )
      )
    )
  end

  # Execute the tool and forget the memory.
  #
  # Note: unlike `memorize`, forgetting does not require embedding to be on
  # — clearing a tag never re-embeds anything.
  #
  # @param tool_call [OllamaChat::Tool::Call] the tool call object
  #
  # @return [String] a JSON string with the result
  def execute(tool_call, **opts)

    args = tool_call.function.arguments
    timestamp = args.timestamp.full?(:strip) or
      raise OllamaChat::ToolFunctionArgumentError, 'blank timestamp'

    persona_name = args.persona_name.full?(:strip) or
      raise OllamaChat::ToolFunctionArgumentError, 'blank persona_name'

    chat.persona_exist?(persona_name) or
      raise OllamaChat::ToolFunctionArgumentError,
      'persona %s does not exist' % persona_name

    collection = "memory-#{persona_name}"

    unless chat.database_collection?(collection)
      raise OllamaChat::ToolFunctionArgumentError,
        "collection #{collection.inspect} does not exist"
    end

    records = []

    chat.switch_collection(collection) do
      records = chat.documents.records(tags: [ timestamp ])
      chat.documents.clear(tags: [ timestamp ])
    end

    forgotten = records.size

    chat.log(:info, 'Memory forgotten',
             data: { tool: name, collection:, forgotten: })

    texts   = records.map(&:text)
    snippet = texts.first&.strip&.[](0, 80)

    message = if forgotten.positive?
      snippet ? "Forgot memory in #{collection.inspect}: " \
                    "\"#{snippet}…\"" :
                "Forgot #{forgotten} memories in " \
                    "collection #{collection.inspect}."
    else
      "No memory with timestamp #{timestamp.inspect} " \
        "found in #{collection.inspect}."
    end

    {
      success:        true,
      timestamp:      ,
      collection:     ,
      forgotten:      ,
      forgotten_text: texts.join("\n").full?,
      message:
    }.to_json
  rescue => e
    chat.log(:error, e, data: { tool: name })
    { error: e.class, message: e.message }.to_json
  end

  self
end.register
