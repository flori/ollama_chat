# A tool for applying unified diffs to files.
#
# This tool enables the chat client to apply patch content (unified diff format)
# directly to existing files on the local filesystem. It supports both overwriting
# and appending modes, with configurable file permissions and safety checks to prevent
# writing to unauthorized locations.
class OllamaChat::Tools::PatchFile
  include OllamaChat::Tools::Concern
  include OllamaChat::Utils::PathValidator

  # @return [String] the registered name for this tool
  def self.register_name = 'patch_file'

  # The tool method creates and returns a tool definition for applying patches
  # to files.
  #
  # @return [Ollama::Tool] a tool definition for patching content in files
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: <<~EOT,
          Patch applicator – Applies **unified diff format** patches given as
          diff_content to existing files. Path of the patched file must be
          given and be allowed, returns JSON with success or
          failure result. Do not not call this tool function unless explicitly
          requested by the user.
        EOT
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            path: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The path to the file to patch (must be within allowed directories)'
            ),
            diff_content: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'Unified diff content to apply'
            )
          },
          required: %w[path diff_content]
        )
      )
    )
  end

  # The execute method processes a tool call to patch a file.
  #
  # This method handles applying unified diffs (like those from git) to files
  # on the local filesystem. It validates that the target path is within
  # allowed directories and ensures the parent directory exists before writing.
  #
  # @param tool_call [Ollama::Tool::Call] the tool call containing function details
  # @param opts [Hash] additional options
  # @option opts [ComplexConfig::Settings] :chat the chat instance
  #
  # @return [String] the result of the patch operation as a JSON string
  # @return [String] a JSON string containing error information if the operation fails
  def execute(tool_call, **opts)
    config = opts[:chat].config
    args   = tool_call.function.arguments

    diff_content = args.diff_content.full? or
      raise ArgumentError, 'require diff_content to patch with'

    path = args.path.full? or raise ArgumentError, 'require path to file to be patched'
    path = assert_valid_path(path, config.tools.functions.patch_file.allowed?, check_file: true)

    result = apply_patch(path, diff_content)
    message = result[:success] ?
      "Successfully applied patch to #{path.to_s.inspect}." :
      "Failed to apply patch to file #{path.to_s.inspect}."
    (result | {
      path:    path.to_s,
      message: ,
    }).to_json
  rescue => e
    {
      error:   e.class,
      success: false,
      message: "Failed to apply patch to file #{path.to_s.inspect}: #{e.message}",
      result:  '',
    }.to_json
  end

  private

  # Computes the MD5 digest of the file located at the given path @param path [
  # String ] the path to the file whose digest is computed
  #
  # @return [ Digest::MD5 ] the MD5 digest of the file
  def digest(path)
    Digest::MD5.file(path)
  end

  # Apply the unified diff content to a target file.
  #
  # @param path [Pathname] The file path to patch
  # @param diff_content [String] Unified diff format string
  def apply_patch(path, diff_content)
    old_digest = digest(path)
    cmd = Shellwords.join(
      [ OC::OLLAMA::CHAT::TOOLS::PATCH_TOOL, '-u', '-f', path ]
    )
    cmd << " 2>&1"
    result = { result: '', success: false }
    IO.popen(cmd, 'r+') do |output|
      output.puts diff_content
      output.close_write
      result[:result]  = output.read
    end
    result[:success] = $?.success? && digest(path) != old_digest
    result
  end

  self
end.register
