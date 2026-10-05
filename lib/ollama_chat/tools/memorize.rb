# A tool for storing a persistent memory entry in a per-persona
# documentrix collection.
#
# This class implements a tool that embeds a short text into the
# `memory-<persona_name>` collection, making it retrievable via
# `search_knowledge`.
#
# @example Storing a memory:
#   memorize(text: 'The important document is at ~/Documents/Secrets/',
#            persona_name: 'sarah')
#
# @example Retrieving it later:
#   search_knowledge(query: 'important document',
#                    collection: 'memory-sarah')
class OllamaChat::Tools::Memorize
  include OllamaChat::Tools::Concern

  # @return [String] the registered name for this tool
  def self.register_name = 'memorize'

  # Build the function signature for the tool.
  #
  # @return [Ollama::Tool] a tool definition for storing a memory entry
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: <<~EOT,
          Store a persistent memory entry in the persona's memory
          collection. The entry is embedded via the embedding model and
          can later be retrieved with `search_knowledge` using
          collection: "memory-<persona_name>".
          Use for facts, decisions, feelings, locations, preferences,
          or open threads worth remembering across sessions.
          Provide `update` to replace an existing entry identified by
          its timestamp tag.
        EOT
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            text: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: <<~EOT,
                The memory content to store. Write in first person,
                in the character's own voice. Keep it to one or two
                lines. A timestamp is prepended automatically.
              EOT
            ),
            persona_name: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: <<~EOT,
                The persona name (e.g. 'sarah', 'miyu_pairing').
                The memory is stored in the collection
                'memory-<persona_name>'.
              EOT
            ),
            update: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: <<~EOT,
                Optional. The ISO 8601 timestamp tag of an existing
                memory to replace. When given, that entry is cleared
                before the new one is stored. E.g.
                '2026-09-29T23:12:57+02:00'.
              EOT
            ),
          },
          required: %w[text persona_name]
        )
      )
    )
  end

  # Execute the tool and store the memory.
  #
  # @param tool_call [OllamaChat::Tool::Call] the tool call object
  #
  # @return [String] a JSON string with the result
  def execute(tool_call, **opts)
    chat.embedding.on? or
      raise OllamaChat::OllamaChatError, 'embedding is disabled'

    args = tool_call.function.arguments
    text = args.text.full?(:strip) or
      raise OllamaChat::ToolFunctionArgumentError, 'blank text'

    persona_name = args.persona_name.full?(:strip) or
      raise OllamaChat::ToolFunctionArgumentError, 'blank persona_name'

    chat.persona_exist?(persona_name) or
      raise OllamaChat::ToolFunctionArgumentError,
      'persona %s does not exist' % persona_name

    collection = chat.create_memory_collection(persona_name)

    update        = args.update&.full?(:strip)
    replaced_text = nil

    timestamp = Time.now.iso8601

    chat.switch_collection(collection) do
      if update
        records = chat.documents.records(tags: [ update ])
        records.empty? and
          raise OllamaChat::ToolFunctionArgumentError,
          "No memory with timestamp #{update.inspect} " \
          "found in #{collection.inspect}."
        replaced_text = records.map(&:text).join("\n").full?
        chat.documents.clear(tags: [ update ])
      end
      chat.documents.add(
        ["#{timestamp}: #{text}"],
        tags: [ timestamp ],
        batch_size: 1,
      )
    end

    chat.log(:info, 'Memory stored',
             data: { tool: name, collection:, text:, update: })

    message = update ?
      "Replaced memory ##{update} in #{collection.inspect}.\n" \
      "New entry tagged ##{timestamp}." :
      "Memory stored in collection #{collection.inspect}."

    result = { success: true, timestamp:, collection:, message: }
    if update
      result |= {
        replaced_timestamp: update,
        replaced_text:      ,
      }
    end

    result.to_json
  rescue => e
    chat.log(:error, e, data: { tool: name })
    { error: e.class, message: e.message }.to_json
  end

  self
end.register
