# A tool for proposing changes to a file through an interactive diff session.
#
# This tool allows the assistant to propose a new version of a file. The
# proposed content is written to a temporary file and opened in a diff tool
# (e.g., vimdiff) alongside the original file, enabling the user to selectively
# apply changes.
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
          Patch applicator – Proposes changes to an existing file by providing
          its full updated content. The tool writes the proposed content to a
          temporary file and launches a interactive diff session (e.g.,
          vimdiff) between the current file and the proposal, allowing the
          user to selectively apply changes. Path of the file must be given,
          existing, and be allowed.

          Returns JSON with success or failure result. In the success case
          a backup is created from the unchanged file.

          Do not call this tool function unless explicitly requested by the
          user.
        EOT
        parameters: Tool::Function::Parameters.new(
          type: 'object',
          properties: {
            path: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The path to the file to patch (must be within allowed directories)'
            ),
            content: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The full updated content of the file to be proposed'
            )
          },
          required: %w[path content]
        )
      )
    )
  end

  # Processes a tool call to initiate a file patch review session.
  #
  # This method validates the arguments and the target path, then triggers the
  # interactive patching process.
  #
  # @param tool_call [Ollama::Tool::Call] the tool call containing function details
  # @param opts [Hash] additional options
  # @option opts [ComplexConfig::Settings] :chat the chat instance
  #
  # @return [String] a JSON string containing the result of the operation
  def execute(tool_call, **opts)
    chat   = opts[:chat]
    config = chat.config
    args   = tool_call.function.arguments

    content = args.content.full? or
      raise OllamaChat::ToolFunctionArgumentError, 'require content to patch file path with'

    path = args.path.full? or raise OllamaChat::ToolFunctionArgumentError, 'require path to file to be patched'
    path = assert_valid_path(path, config.tools.functions.patch_file.allowed?, check: :file)

    result = apply_patch(chat, path, content)
    message =
      if result[:success]
        "Successfully applied patch to #{path.to_s.inspect}."
      elsif result[:content_unchanged]
        "User rejected to apply patch to file #{path.to_s.inspect}. Ask the user about what you did wrong."
      else
        "Failed to apply patch to file #{path.to_s.inspect}."
      end
    (result | {
      path:    path.to_s,
      message: ,
    }).to_json
  rescue => e
    {
      error:   e.class,
      success: false,
      message: "Failed to apply patch to file #{path.to_s.inspect}: #{e.message}",
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

  # Launches an interactive diff session to apply proposed changes.
  #
  # Writes the proposed content to a temporary file and opens the configured
  # diff tool (e.g., vimdiff). Success is determined by whether the original
  # file's content changed after the session.
  #
  # @param path [Pathname] The path to the existing file
  # @param content [String] The proposed new content
  #
  # @return [Hash] result containing success status and any output
  def apply_patch(chat, path, content)
    old_digest = digest(path)
    diff_tool  = OC::DIFF_TOOL? or raise 'Diff tool not defined in env var DIFF_TOOL'
    File.exist?(diff_tool) or raise "Diff tool #{diff_tool.inspect} does not exist"
    result      = { success: false }
    basename    = [ path.basename.sub_ext(''), path.extname.full? ].compact.map(&:to_s)
    backup_path = nil
    chat.edit_text_block(content, basename:) do |patched|
      cmd = [ diff_tool, path, patched.path ].map(&:to_s)
      backup_path = perform_backup path
      if system(*cmd)
        if result[:success] = $?.success?
          result[:content_unchanged] = digest(path) == old_digest
          if result[:content_unchanged]
            backup_path.delete
          else
            result[:backup_path] = backup_path
          end
          result[:success] &&= !result[:content_unchanged]
        end
      end
    end
    return result
  end

  self
end.register
