require "shellwords"

class OllamaChat::Tools::Browser
  include OllamaChat::Tools::Concern

  def self.register_name = 'browse'

  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: <<~EOT,
          Open a URL in the user\'s default browser application so they can
          view the content directly
        EOT
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            url: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: <<~EOT,
                The URL to open in the user\'s browser for them to view
                directly
              EOT
            ),
          },
          required: %w[url]
        )
      )
    )
  end

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

  def browse_url(url)
    browser = OllamaChat::EnvConfig::BROWSER? || "open"
    system %{#{browser} #{Shellwords.escape(url)}}
    $?
  end

  self
end.register
