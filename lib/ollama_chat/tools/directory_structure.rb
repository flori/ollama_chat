# A tool for retrieving directory structure and file hierarchy.
#
# This tool allows the chat client to retrieve the directory structure and file
# hierarchy for a given path. It integrates with the Ollama tool calling system
# to provide detailed directory information to the language model.
#
# The tool supports traversing directories up to a specified depth and returns
# a structured representation of the file system hierarchy.
class OllamaChat::Tools::DirectoryStructure
  include Ollama

  # Initializes a new directory_structure tool instance.
  #
  # @return [OllamaChat::Tools::DirectoryStructure] a new directory_structure tool instance
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
  # does, its parameters, and required fields. The tool accepts path and depth
  # parameters for directory traversal.
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
            depth: Tool::Function::Parameters::Property.new(
              type: 'integer',
              description: 'Depth of directory traversal (defaults to 2)'
            )
          },
          required: []
        )
      )
    )
  end

  # Executes the directory structure retrieval operation.
  #
  # This method traverses the directory structure starting from the specified
  # path up to the given depth and returns a structured representation of
  # the file system hierarchy.
  #
  # @param tool_call [Ollama::Tool::Call] the tool call object containing function details
  # @param opts [Hash] additional options
  # @return [String] the directory structure as a JSON string
  # @raise [StandardError] if there's an issue with directory traversal or JSON serialization
  def execute(tool_call, **opts)
    path = Pathname.new(tool_call.function.arguments.path || '.')
    depth = (tool_call.function.arguments.depth || 2).to_i

    structure = generate_structure(path, depth)
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

  private

  # Generates the directory structure recursively.
  #
  # This method traverses the directory tree recursively up to the specified depth
  # and builds a structured representation of files and directories.
  #
  # @param path [Pathname] the path to traverse
  # @param depth [Integer] the maximum depth to traverse
  # @param current_depth [Integer] the current traversal depth (used internally)
  # @return [Array<Hash>, Hash] an array of directory and file entries, or an
  #   error hash if an exception occurs
  def generate_structure(path, depth, current_depth = 0)
    return [] if current_depth > depth

    entries = []
    path.children.sort.each do |child|
      # Skip hidden files/directories
      next if child.basename.to_s.start_with?('.')

      if child.directory?
        entries << {
          type: 'directory',
          name: child.basename.to_s,
          children: generate_structure(child, depth, current_depth + 1)
        }
      else
        entries << {
          type: 'file',
          name: child.basename.to_s
        }
      end
    end
    entries
  rescue => e
    { error: e.class, message: e.message }
  end
end
