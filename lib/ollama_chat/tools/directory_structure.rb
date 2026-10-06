# A tool for retrieving directory structure and file hierarchy.
#
# This tool allows the chat client to retrieve the directory structure and file
# hierarchy for a given path. It integrates with the Ollama tool calling system
# to provide detailed directory information to the language model.
#
# The tool supports traversing directories and returns a structured
# representation of the file system hierarchy.
class OllamaChat::Tools::DirectoryStructure
  include OllamaChat::Tools::Concern
  include OllamaChat::Utils::AnalyzeDirectory

  # @return [String] the registered name for this tool
  def self.register_name = 'directory_structure'

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
        description: <<~EOT,
          File locator – Returns a JSON tree of files/folders under
          path, optionally filtered by suffix (e. g. "rb") and
          max_depth. Prefer this over shell `find` or `ls -R`: it
          shows where files sit relative to each other, which flat
          `find` output cannot. Use max_depth to keep the result
          small — nodes grow exponentially with tree height.
        EOT
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            path: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'Path to directory to list (defaults to current directory)'
            ),
            suffix: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: <<~EOT
                Only include files with this suffix / file extension, e. g.
                "rb" (defaults to all)
              EOT
            ),
            max_depth: Tool::Function::Parameters::Property.new(
              type: 'integer',
              description: <<~EOT,
                How many levels of the tree to include. 1 = immediate
                children only, 2 = children + grandchildren, nil =
                unlimited (defaults to nil)
              EOT
            ),
            include_hidden: Tool::Function::Parameters::Property.new(
              type: 'boolean',
              description: 'Include hidden files and directories (dotfiles), (default: false)'
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

    path           = Pathname.new(tool_call.function.arguments.path || '.')
    suffix         = tool_call.function.arguments.suffix.full?
    max_depth      = tool_call.function.arguments.max_depth.full?
    include_hidden = tool_call.function.arguments.include_hidden

    structure = generate_structure(
      path,
      max_depth:,
      suffix:,
      include_hidden:,
      exclude: tool_config.exclude?,
    )
    structure.to_json
  rescue => e
    chat.log(:error, e, data: { tool: name, path: path.to_s })
    { error: e.class, message: e.message }.to_json
  end

  self
end.register
