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

  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: <<~EOT,
          Create a context that provides information about files and their
          content in order to give more accurate answers for a query. You can either
          query (maybe) multiple files by combining the directory and pattern
          arguments **OR** using an exact path as argument to get a single file
          context.
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
            ),
            path: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'Exact path to a file (alternative to glob pattern)'
            ),
          },
          required: []
        )
      )
    )
  end

  def execute(tool_call, **opts)
    config      = opts[:config]
    pattern     = tool_call.function.arguments.pattern
    path        = tool_call.function.arguments.path
    unless pattern.blank? ^ path.blank?
      raise ArgumentError, "require either pattern or path argument"
    end
    format      = config.context.format
    if pattern
      directory   = Pathname.new(tool_call.function.arguments.directory || ?.)
      search_path = directory + pattern
    else
      search_path = path
    end

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
