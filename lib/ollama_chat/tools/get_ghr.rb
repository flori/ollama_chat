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
        description: <<~EOT,
          Fetch GitHub release information via the GHR API.

          This tool operates in two modes:
          1. Overview Mode: Omit both 'user' and 'repo' to retrieve a general
             overview of all tracked repositories, including their user:repo
             pairs.
          2. Specific Release Mode: Provide both 'user' and 'repo' to fetch
             releases for a specific repository, sorted by version descending. If
             the repository is not registered at GHR, a 404 error is returned.

          Pagination using 'offset' and 'limit' parameters is supported in both
          modes.
        EOT
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            user: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The GitHub username or organization (e.g., "flori").',
            ),
            repo: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The GitHub repository name (e.g., \"ghr\").',
            ),
            offset: Tool::Function::Parameters::Property.new(
              type: 'integer',
              description: 'The number of records to skip (default: 0).',
            ),
            limit: Tool::Function::Parameters::Property.new(
              type: 'integer',
              description: 'The maximum number of records to return (default: 10).',
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
    offset = args.offset.full?
    limit = args.limit.full?

    ghr_url = OC::OLLAMA::CHAT::TOOLS::GHR_URL or
      raise '%s env var not configured' % OC::OLLAMA::CHAT::TOOLS::GHR_URL!.env_var_name

    if user && repo
      url = ghr_url + "/repos/#{user}:#{repo}/releases.json"
    elsif !user && !repo
      url = ghr_url + '/repos.json'
    else
      raise OllamaChat::ToolFunctionArgumentError,
        'Both user and repo must be provided for a specific lookup, or both omitted for an overview.'
    end

    query = []
    query << "offset=#{offset}" if offset
    query << "limit=#{limit}" if limit
    url.query = query.full? { _1 * ?& }

    data = get_ghr_data(chat, url)

    if user && repo
      { user:, repo: }.stringify_keys.merge(data).to_json
    else
      data.to_json
    end
  rescue => e
    { error: e.class, message: e.message, user:, repo: }.to_json
  end

  private

  def get_ghr_data(chat, url)
    headers = {
      'Accept' => 'application/json',
    }
    content = chat.get_url(url, headers:, &valid_json?)
    JSON.parse(content)
  end

  self
end.register
