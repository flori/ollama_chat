# Provides functionality to generate an image using a locally hosted ComfyUI server.
# The class registers itself as a tool and implements the asynchronous
# prompt-to-image pipeline: /prompt -> /history -> /view.
class OllamaChat::Tools::GenerateImage
  include OllamaChat::Tools::Concern

  # Register the tool name for the Ollama tool-calling system.
  #
  # @return [String] the unique identifier for this tool
  def self.register_name = 'generate_image'

  # The tool method creates and returns a tool definition for generating an image.
  #
  # @return [Ollama::Tool] a tool definition for image generation
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: <<~EOT,
          Image generator – Generates an image using a local ComfyUI server based on a text prompt.
          Returns a URL to the generated image.
        EOT
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            prompt: {
              type: 'string',
              description: 'The descriptive text prompt for the image generation'
            },
            filename_prefix: {
              type: 'string',
              description: 'Optional prefix for the generated image filename'
            }
          },
          required: ['prompt']
        )
      )
    )
  end

  # Executes the image generation process.
  #
  # @param tool_call [Object] the tool call object containing the prompt
  # @param opts [Hash] additional options
  # @option opts [ComplexConfig::Settings] :chat the chat instance
  #
  # @return [String] a JSON string containing either the success URL or an error message
  def execute(tool_call, **opts)
    chat   = opts[:chat]
    config = chat.config
    args   = tool_call.function.arguments
    prompt = args.prompt.full? or
      raise OllamaChat::ToolFunctionArgumentError, 'require prompt argument for image generation'
    prefix = args.filename_prefix.full? || 'comfy-ui-image'

    # 1. Prepare the workflow
    #
    service_url = OC::OLLAMA::CHAT::TOOLS::IMAGE_GENERATOR::URL? or
      raise OllamaChat::ConfigMissingError,
        'Require env var %s configuration for ComfyUI' %
          OC::OLLAMA::CHAT::TOOLS::IMAGE_GENERATOR::URL!.env_var_name
    workflow    = OC::OLLAMA::CHAT::TOOLS::IMAGE_GENERATOR::WORKFLOW.dup
    prompt_node = OC::OLLAMA::CHAT::TOOLS::IMAGE_GENERATOR::PROMPT_NODE_ID
    prefix_node = OC::OLLAMA::CHAT::TOOLS::IMAGE_GENERATOR::FILENAME_PREFIX_NODE_ID?

    workflow.key?(prompt_node) or raise OllamaChat::OllamaChatError,
      'ComfyUI workflow or prompt node ID is missing'

    workflow[prompt_node]['inputs']['text'] = prompt

    if prefix_node && workflow.key?(prefix_node)
      workflow[prefix_node]['inputs']['filename_prefix'] = prefix
    end

    # 2. Trigger generation
    url        = service_url + '/prompt'
    payload    = { prompt: workflow }
    started    = Time.now
    prompt_id  = post_url(url, payload).prompt_id

    prompt_id.nil? and raise OllamaChat::OllamaChatError,
      "failed to trigger ComfyUI with #{prompt_id}"

    # 3. Poll for completion
    filename = poll_for_image(service_url, prompt_id, config)

    filename.nil? and raise OllamaChat::OllamaChatError,
       'Image generation took too long or failed'

    # 4. Construct the final view URL
    # Example: http://host:port/api/view?filename=...&subfolder=&type=output&rand=...
    view_url       = service_url + '/api/view'
    view_url.query = URI.encode_www_form(
      filename:, subfolder: '', type: 'output', rand:
    )

    message = "Image successfully generated! The user can view it here,"\
      " give this URL to the user: #{view_url}"
    {
      status:   'success',
      message:  ,
      url:      view_url,
      prompt:   ,
      duration: Tins::Duration.new(Time.now - started).to_s,
    }.to_json
  rescue => e
    {
      error:    e.class,
      message: "Failed to generate image: #{e.message}",
      prompt:   ,
    }.to_json
  end

  private

  # Sends a POST request to the specified URL with a JSON payload.
  #
  # @param url [URI] the target URL
  # @param payload [Hash] the data to be sent as JSON
  # @return [JSON::GenericObject] the parsed JSON response
  def post_url(url, payload)
    response = Excon.post(
      url,
      body: JSON.dump(payload),
      headers: { 'Content-Type' => 'application/json' },
      expects: 200
    )
    JSON.parse(response.body, object_class: JSON::GenericObject)
  end

  # Sends a GET request to the specified URL.
  #
  # @param url [URI] the target URL
  # @return [JSON::GenericObject] the parsed JSON response
  def get_url(url)
    response = Excon.get(
      url,
      headers: { 'Accept' => 'application/json' },
      expects: 200
    )
    JSON.parse(response.body, object_class: JSON::GenericObject)
  end

  # Polls the ComfyUI history endpoint until the image is generated or timeout is reached.
  #
  # @param service_url [URI] the base URL of the ComfyUI server
  # @param prompt_id [String] the ID of the prompt to track
  # @param config [ComplexConfig::Settings] the configuration settings for timeout
  # @return [String, nil] the filename of the generated image, or nil if it timed out
  def poll_for_image(service_url, prompt_id, config)
    history_url = service_url + '/history'
    filename = nil

    attempts = config.tools.functions.generate_image.timeout_attempts? || 20
    sleep    = -(config.tools.functions.generate_image.timeout_duration? || 60)

    attempt attempts:, sleep:, exception_class: nil do
      response = get_url(history_url)
      output_data = response[prompt_id]

      if filename = output_data&.outputs&.each_pair&.first&.last&.images&.first&.filename
        true # Stop attempting
      else
        false # Keep attempting
      end
    end

    filename
  end

  self
end.register
