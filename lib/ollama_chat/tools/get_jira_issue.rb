# A tool for fetching JIRA issue information.
#
# This tool allows the chat client to retrieve JIRA issue details by key.
# It integrates with the Ollama tool calling system to provide project
# management information to the language model.
class OllamaChat::Tools::GetJiraIssue
  include OllamaChat::Tools::Concern

  def self.register_name = 'get_jira_issue'

  # Creates and returns a tool definition for getting JIRA issue information.
  #
  # This method constructs the function signature that describes what the tool
  # does, its parameters, and required fields. The tool expects a JIRA issue key
  # parameter to be provided.
  #
  # @return [Ollama::Tool] a tool definition for retrieving JIRA issue information
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: 'Get the JIRA issue for key as JSON',
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            issue_key: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The JIRA issue key to get'
            ),
          },
          required: %w[issue_key]
        )
      )
    )
  end

  # Executes the JIRA lookup operation.
  #
  # This method fetches JIRA issue data from the configured API endpoint using
  # the provided issue key. It handles the HTTP request, parses the JSON response,
  # and returns the structured data.
  #
  # @param tool_call [Ollama::Tool::Call] the tool call object containing function details
  # @param opts [Hash] additional options
  # @option opts [ComplexConfig::Settings] :config the configuration object
  # @return [String] the parsed JIRA issue data or an error message as JSON string
  def execute(tool_call, **opts)
    issue_key = tool_call.function.arguments.issue_key
    fetch_issue(issue_key)
  rescue => e
    { error: e.class, message: e.message }.to_json
  end

  # The fetch_issue method retrieves JIRA issue data by key from the configured
  # JIRA instance.
  #
  # This method constructs the appropriate API endpoint URL using the base URL,
  # user, and API token configured in the environment, then fetches the issue
  # data using the configured fetcher.
  #
  # @param issue_key [ String ] the JIRA issue key to retrieve
  #
  # @return [ String ] the JSON response containing the JIRA issue data
  def fetch_issue(issue_key)
    # Construct the JIRA API URL
    env          = OllamaChat::EnvConfig::OLLAMA::CHAT::TOOLS::JIRA
    base_url     = env::URL? or raise OllamaChat::ConfigMissingError, 'need … URL'
    url          = "#{base_url}/rest/api/3/issue/#{issue_key}"

    # Fetch the data from JIRA API
    fetcher = OllamaChat::Utils::Fetcher.new(
      debug: OllamaChat::EnvConfig::OLLAMA::CHAT::DEBUG,
    )
    fetcher.get(
      url,
      user:     env::USER,
      password: env::API_TOKEN,
      &valid_json?
    )
  end

  self
end.register
