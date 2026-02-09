# A tool for creating file context based on glob patterns.
#
# This tool allows the chat client to generate context information about files
# matching a specified glob pattern. It integrates with the Ollama tool calling
# system to provide detailed file information to the language model for more
# accurate responses.
#
# The tool searches for files using the provided glob pattern and generates
# structured context data that includes file contents, sizes, and metadata.
class OllamaChat::Tools::FileContext
  include OllamaChat::Tools::Concern

  def self.register_name = 'file_context'

  # Returns the tool definition for the Ollama tool calling system
  #
  # This method constructs and returns the tool definition that describes
  # the file context tool's capabilities to the LLM. It defines the tool's
  # name, description, and parameters for the function calling interface.
  #
  # @return [Ollama::Tool] the tool definition for the Ollama system
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: <<~EOT,
          Create a context that provides information about files and their
          semantic content in order to give more accurate answers for a query.
          You can query (maybe) multiple files by using a glob pattern
          argument.
        EOT
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            pattern: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'Glob pattern to search for (e.g., "**/*.rb", "lib/**/*.rb")'
            ),
            directory: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'Directory to search in (defaults to current directory)'
            )
          },
          required: []
        )
      )
    )
  end

  # The execute method processes a tool call to generate context information
  # for files matching a pattern or specific path.
  #
  # This method handles both glob pattern matching and exact path queries to
  # collect file context using the ContextSpook library. It supports both
  # directory traversal with patterns and direct file access,
  # returning structured context data in the configured format.
  #
  # @param tool_call [Ollama::Tool::Call] the tool call containing function details
  # @param opts [Hash] additional options
  # @option opts [ComplexConfig::Settings] :config the configuration object
  #
  # @return [String] the generated context data in the configured format (JSON by default)
  # @return [String] a JSON string containing error information if the operation fails
  def execute(tool_call, **opts)
    config      = opts[:config]
    pattern     = tool_call.function.arguments.pattern
    format      = config.context.format

    directory   = Pathname.new(tool_call.function.arguments.directory || ?.)
    search_path = directory + pattern

    ContextSpook::generate_context(verbose: true, format:) do |context|
      context do
        Dir.glob(search_path).each do |filename|
          File.file?(filename) or next
          file filename
        end
      end
    end.send("to_#{format.downcase}")
  rescue => e
    { error: e.class, message: e.message }.to_json
  end

  self
end.register
