# A tool for fetching GitHub release information via the GHR API.
#
# This tool allows the chat client to retrieve a list of releases for a specific
# GitHub repository using the GHR service, which provides a JSON interface
# for GitHub releases.
class OllamaChat::Tools::GetGHR
  include OllamaChat::Tools::Concern

  # @return [String] the registered name for this tool
  def self.register_name = 'get_ghr'

  # Creates and returns a tool definition for fetching GitHub releases.
  #
  # This method constructs the function signature that describes what the tool
  # does, its parameters, and required fields. The tool expects the GitHub
  # user/organization and the repository name, but can also be called without
  # arguments to see an overview of tracked repositories.
  #
  # @return [Ollama::Tool] a tool definition for retrieving release info
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: 'Fetch GitHub release information via the GHR API. Provide user and repo for specific releases, or omit both for a general overview of tracked repositories.',
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            user: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The GitHub username or organization (e.g., "acidanthera").',
            ),
            repo: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The GitHub repository name (e.g., "AppleALC").',
            ),
          },
          required: []
        )
      )
    )
  end

  # Executes the GHR API request.
  #
  # This method constructs the API URL and performs an HTTP GET request with
  # the 'Accept: application/json' header to retrieve the releases in JSON format.
  # If no user or repo is provided, it fetches the general repository list.
  #
  # @param tool_call [Ollama::Tool::Call] the tool call object containing function details
  # @param opts [Hash] additional options
  # @option opts [ComplexConfig::Settings] :chat the chat instance
  # @return [String] a JSON string containing the release data or an error message
  # @raise [StandardError] if there's an issue with the HTTP request or JSON parsing
  def execute(tool_call, **opts)
    chat = opts[:chat]
    args = tool_call.function.arguments
    user = args.user.full?
    repo = args.repo.full?

    ghr_url = OC::OLLAMA::CHAT::TOOLS::GHR_URL or
      raise '%s env var not configured' % OC::OLLAMA::CHAT::TOOLS::GHR_URL!.env_var_name

    if user && repo
      url = ghr_url + "/repos/#{user}:#{repo}.json"
    elsif !user && !repo
      url = ghr_url + '/repos.json'
    else
      raise OllamaChat::ToolFunctionArgumentError,
        'Both user and repo must be provided for a specific lookup, or both omitted for an overview.'
    end

    headers = {
      'Accept' => 'application/json',
    }
    content = chat.get_url(url, headers:, reraise: true, &valid_json?)

    if user && repo
      { user:, repo:, releases: JSON.parse(content) }.to_json
    else
      { repos: JSON.parse(content) }.to_json
    end
  rescue => e
    { error: e.class, message: e.message, user:, repo: }.to_json
  end

  self
end.register
