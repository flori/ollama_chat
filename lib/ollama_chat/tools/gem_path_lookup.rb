# A tool for looking up gem paths.
#
# This tool allows the chat client to find the installation paths of gems
# on the system. It integrates with the Ollama tool calling system to
# provide gem path information to the language model.
class OllamaChat::Tools::GemPathLookup
  include OllamaChat::Tools::Concern

  # @return [String] the registered name for this tool
  def self.register_name
    'gem_path_lookup'
  end

  # Creates and returns a tool definition for gem path lookup.
  #
  # This method constructs the function signature that describes what the tool
  # does, its parameters, and required fields. The tool expects a gem name
  # parameter to be provided.
  #
  # @return [Ollama::Tool] a tool definition for retrieving gem paths
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: 'Look up the installation path of a Ruby gem',
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            gem_name: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The name of the gem to look up'
            ),
          },
          required: %w[gem_name]
        )
      )
    )
  end

  # Executes the gem path lookup tool.
  #
  # This method processes a tool call to find the installation path of a Ruby gem.
  #
  # @param tool_call [Ollama::Tool::Call] the tool call containing the gem name
  # @param opts [Hash] additional options
  # @return [String] the result of the gem path lookup
  def execute(tool_call, **opts)
    gem_name = tool_call.function.arguments.gem_name
    lookup_gem_path gem_name
  end

  private

  # Looks up the installation path of a Ruby gem.
  #
  # This method uses Bundler to find the gem in the locked dependencies and
  # then retrieves the actual gem specification to determine its installation path.
  #
  # @param gem_name [String] the name of the gem to look up
  # @return [String] a JSON string containing gem information or JSON error string
  def lookup_gem_path(gem_name)
    # Use Bundler to find the gem in the locked dependencies
    require 'bundler'

    gem_spec = nil

    if lazy_spec = Bundler.locked_gems.specs.find { |spec| spec.name == gem_name }
      gem_spec = Gem::Specification.find_by_full_name(lazy_spec.full_name)
    end

    if gem_spec
      {
        gem_name: gem_name,
        path: gem_spec.gem_dir,
        version: gem_spec.version,
        found: true,
        message: "Found gem '#{gem_name}' at #{gem_spec.gem_dir.inspect}"
      }.to_json
    else
      {
        gem_name: gem_name,
        path: nil,
        found: false,
        message: "Gem '#{gem_name}' not found in bundle"
      }.to_json
    end
  rescue => e
    {
      error: e.class,
      message: e.message
    }.to_json
  end

  self
end.register
