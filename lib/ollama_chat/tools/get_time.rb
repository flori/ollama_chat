require 'time'

module OllamaChat
  module Tools
    # A tool for retrieving the current time as an ISO8601 string.
    #
    # This class implements a tool that returns the current time in ISO8601 format.
    # It's registered with the Ollama tool calling system and can be invoked by name.
    #
    # @example Usage in a chat session:
    #   ollama_chat.run('get_time')
    #   # => "{\"time\":\"2026-02-09T14:32:00+01:00\"}"
    class GetTime
      include OllamaChat::Tools::Concern

      # Register the tool name for the Ollama tool‑calling system.
      #
      # @return [String] the registered tool name 'get_time'
      def self.register_name = 'get_time'

      # Build the function signature for the tool.
      #
      # This method constructs the function signature that describes the tool's
      # capabilities, parameters, and usage for the LLM. The tool has no
      # parameters and simply returns the current time.
      #
      # @return [Ollama::Tool] a tool definition for retrieving the current time
      def tool
        Tool.new(
          type: 'function',
          function: Tool::Function.new(
            name:,
            description: 'Get the current time as an ISO8601 string',
            parameters: Tool::Function::Parameters.new(
              type: 'object',
              properties: {},
              required: []
            )
          )
        )
      end

      # Execute the tool and return the current time.
      #
      # This method retrieves the current time from the system and returns it
      # as an ISO8601 formatted string. The time includes timezone information
      # and is serialized as JSON for easy parsing by the caller.
      #
      # @param _tool_call [OllamaChat::Tool::Call] the tool call object (unused, as the tool has no parameters)
      # @param _opts [Hash] additional options (unused)
      #
      # @return [String] a JSON string containing the current time in ISO8601 format with a `time` key
      #
      # @example
      #   execute(tool_call, config:)
      #   # => "{\"time\":\"2026-02-09T14:32:00+01:00\"}"
      #
      # @see https://en.wikipedia.org/wiki/ISO_8601 ISO 8601
      def execute(_tool_call, **_opts)
        { time: Time.now.iso8601 }.to_json
      end

      self
    end.register
  end
end
