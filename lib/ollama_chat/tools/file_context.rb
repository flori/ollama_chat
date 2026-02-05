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
  include Ollama

  # Initializes a new file_context tool instance.
  #
  # @return [OllamaChat::Tools::FileContext] a new file_context tool instance
  def initialize
    @name = 'file_context'
  end

  # Returns the name of the tool.
  #
  # @return [String] the name of the tool ('file_context')
  attr_reader :name

  # Creates and returns a tool definition for generating file context.
  #
  # This method constructs the function signature that describes what the tool
  # does, its parameters, and required fields. The tool expects a pattern parameter
  # to be provided for file searching.
  #
  # @return [Ollama::Tool] a tool definition for generating file context
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: 'Create a context that provides information about files '\
          'and their content in order to give more accurate answers for a query',
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
            ),
          },
          required: ['pattern']
        )
      )
    )
  end

  # Executes the file context generation operation.
  #
  # This method searches for files matching the provided glob pattern and
  # generates structured context data including file contents, sizes, and metadata.
  #
  # @param tool_call [Ollama::Tool::Call] the tool call object containing function details
  # @param opts [Hash] additional options
  # @option opts [ComplexConfig::Settings] :config the configuration object
  # @return [String] the formatted context data as a string in the configured format
  # @raise [StandardError] if there's an issue with file searching or context generation
  def execute(tool_call, **opts)
    config      = opts[:config]
    pattern     = tool_call.function.arguments.pattern
    directory   = Pathname.new(tool_call.function.arguments.directory || ?.)
    format      = config.context.format
    search_path = directory + pattern

    ContextSpook::generate_context(verbose: true, format:) do |context|
      context do
        Dir.glob(search_path).each do |filename|
          File.file?(filename) or next
          file filename
        end
      end
    end.send("to_#{format.downcase}")
  end

  # Converts the tool to a hash representation.
  #
  # This method provides a standardized way to serialize the tool definition
  # for use in tool calling systems.
  #
  # @return [Hash] a hash representation of the tool
  def to_hash
    tool.to_hash
  end
end
