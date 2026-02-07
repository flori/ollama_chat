require "shellwords"

class OllamaChat::Tools::Browser
  include OllamaChat::Tools::Concern

  def self.register_name = 'browse'

  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: 'Open a URL/file in the default browser',
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            url: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The URL or file to open'
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
