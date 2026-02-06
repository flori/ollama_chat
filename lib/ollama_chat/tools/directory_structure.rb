# A tool for retrieving directory structure and file hierarchy.
#
# This tool allows the chat client to retrieve the directory structure and file
# hierarchy for a given path. It integrates with the Ollama tool calling system
# to provide detailed directory information to the language model.
#
# The tool supports traversing directories and returns a structured
# representation of the file system hierarchy.
class OllamaChat::Tools::DirectoryStructure
  include Ollama
  include OllamaChat::Utils::AnalyzeDirectory

  # Initializes a new directory_structure tool instance.
  #
  # @return [OllamaChat::Tools::DirectoryStructure] a new directory_structure
  #   tool instance
  def initialize
    @name = 'directory_structure'
  end

  # Returns the name of the tool.
  #
  # @return [String] the name of the tool ('directory_structure')
  attr_reader :name

  # Creates and returns a tool definition for retrieving directory structure.
  #
  # This method constructs the function signature that describes what the tool
  # does, its parameters, and required fields. The tool accepts a path
  # parameter for directory traversal.
  #
  # @return [Ollama::Tool] a tool definition for retrieving directory structure
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: 'Retrieve the directory structure and file hierarchy for a given path',
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            path: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'Path to directory to list (defaults to current directory)'
            ),
          },
          required: []
        )
      )
    )
  end

  # Executes the directory structure retrieval operation.
  #
  # This method traverses the directory structure starting from the specified
  # path and returns a structured representation of the file system hierarchy.
  #
  # @param tool_call [Ollama::Tool::Call] the tool call object containing
  #   function details
  #
  # @param opts [Hash] additional options
  # @return [String] the directory structure as a JSON string
  # @raise [StandardError] if there's an issue with directory traversal or JSON
  #   serialization
  def execute(tool_call, **opts)
    path = Pathname.new(tool_call.function.arguments.path || '.')

    structure = generate_structure(path)
    structure.to_json
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
