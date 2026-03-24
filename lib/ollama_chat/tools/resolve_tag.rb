# A tool for resolving a symbol definition using the tags file.
#
# This tool allows the chat client to look up a Ruby tag and return the exact
# file:line where it is defined.  It follows the same interface conventions as
# other tools in this repository, making it easy to integrate with the Ollama
# API.
class OllamaChat::Tools::ResolveTag
  include OllamaChat::Tools::Concern

  # @return [String] the registered name for this tool
  def self.register_name = 'resolve_tag'

  # Returns a Tool definition that describes this functionality to
  # the LLM.
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: <<~EOT,
          Class/Method finder - Resolve a symbol of a kind using the tags file
          and return its location as "file.rb:<linenumber>". This tool can
          answer prompts like "Open class FooBar" or "Show the location of
          method baz".
        EOT
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            symbol: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The name of the symbol to resolve, e.g. "execute".'
            ),
            kind: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'Optional tag kind (%s).' % OllamaChat::Utils::TagResolver.kinds.to_json
            ),
            directory: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'Only return tags in files below directory if given (defaults to nil).'
            )
          },
          required: ['symbol']
        )
      )
    )
  end

  # The resolve_tags method resolves a symbol in the tag file and returns its
  # results as JSON.
  #
  # It accepts a tool call containing arguments for the symbol, optional kind,
  # and directory.
  #
  # It uses TagResolver to find matching tags and returns a JSON string with
  # the symbol, kind, directory, and results.
  #
  # @param tool_call [ToolCall] the tool call object containing function arguments
  # @param _opts [Hash] additional options for execution (currently unused)
  # @return [String] JSON string containing the resolved tag information or error details
  def execute(tool_call, **_opts)
    args      = tool_call.function.arguments
    symbol    = args.symbol.full? or raise ArgumentError, 'require a symbol'
    kind      = args.kind.full?
    directory = args.directory.full?

    tags    = OC::OLLAMA::CHAT::TOOLS::TAGS_FILE
    results = OllamaChat::Utils::TagResolver.new(tags).
      resolve(symbol:, kind:, directory:)

    message = "Found %{results_count} results of symbol \"%{symbol}\"." % {
      results_count: results.size, symbol:
    }

    {
      message: ,
      symbol:   ,
      kind:     ,
      directory:,
      results:  ,
    }.to_json
  rescue => e
    { error: e.class.to_s, message: e.message }.to_json
  end

  self
end.register
