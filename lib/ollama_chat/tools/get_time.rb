require 'time'

# get_time.rb – a tool that returns the current time as an ISO8601 string.
#
# This file mirrors the structure of get_location.rb and can be dropped into
# the `lib/ollama_chat/tools` directory.  The tool is registered with the
# Ollama tool‑calling system and can be invoked by name `get_time`.
#
# Usage in a chat session:
#   ollama_chat.run('get_time')
#   # => "{\"time\":\"2026-02-09T14:32:00+01:00\"}"
#
# The implementation is intentionally lightweight – it simply calls
# `Time.now.iso8601` and serialises the result as JSON.
module OllamaChat
  module Tools
    class GetTime
      include OllamaChat::Tools::Concern

      # Register the tool name for the Ollama tool‑calling system.
      def self.register_name = 'get_time'

      # Build the function signature for the tool.  No parameters are
      # required – the tool simply returns the current time.
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

      # Execute the tool.  We return a JSON string containing the time
      # in ISO8601 format.  The caller can parse it as needed.
      def execute(_tool_call, **_opts)
        { time: Time.now.iso8601 }.to_json
      end

      self
    end.register
  end
end
