require "shellwords"

# A tool for opening URLs/files in the user's default browser application.
#
# This tool enables the chat client to open web URLs or local files in the
# user's default browser, allowing users to view content directly in their
# browser environment. It integrates with the Ollama tool calling system to
# provide
# seamless web browsing capabilities during chat interactions.
class OllamaChat::Tools::Browser
  include OllamaChat::Tools::Concern

  def self.register_name = 'browse'

  # Creates and returns a tool definition for opening URLs/files in the browser.
  #
  # This method constructs the function signature that describes what the tool
  # does, its parameters, and required fields. The tool expects a URL parameter
  # to be provided.
  #
  # @return [Ollama::Tool] a tool definition for opening URLs/files in the browser
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: <<~EOT,
          Open a URL or file in the user\'s default browser application so they
          can view the content directly
        EOT
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            url: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: <<~EOT,
                The URL or file to open in the user\'s browser for them to view
                directly
              EOT
            ),
          },
          required: %w[url]
        )
      )
    )
  end

  # Executes the browser opening operation.
  #
  # This method opens the specified URL or file in the user's default browser
  # application. It handles the system call and returns the result status.
  #
  # @param tool_call [Ollama::Tool::Call] the tool call object containing function details
  # @param opts [Hash] additional options
  # @return [String] the execution result as JSON string
  # @raise [StandardError] if there's an issue with opening the URL/file
  def execute(tool_call, **opts)
    url    = tool_call.function.arguments.url
    result = browse_url(url)
    {
      success:    result.success?,
      exitstatus: result.exitstatus,
      message:    'opening URL/file',
      url:        ,
    }.to_json
  rescue => e
    { error: e.class, message: e.message }.to_json
  end

  private

  # Opens a URL or file in the system browser.
  #
  # This method uses the system's default browser to open the provided URL or file.
  # It respects the BROWSER environment variable if set, otherwise defaults to "open".
  #
  # @param url [String] the URL or file path to open
  # @return [Process::Status] the process status of the system call
  def browse_url(url)
    browser = OllamaChat::EnvConfig::BROWSER? || "open"
    system %{#{browser} #{Shellwords.escape(url)}}
    $?
  end

  self
end.register
