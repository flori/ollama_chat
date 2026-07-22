# A tool for proposing changes to a file through an interactive diff session.
#
# This tool allows the assistant to propose specific line-range replacements.
# The resulting content is written to a temporary file and opened in a diff tool
# (e.g., vimdiff) alongside the original file, enabling the user to selectively
# apply changes.
class OllamaChat::Tools::PatchFile
  include OllamaChat::Tools::Concern
  include OllamaChat::Utils::PathValidator

  # @return [String] the registered name for this tool
  def self.register_name = 'patch_file'

  # The tool method creates and returns a tool definition for applying patches
  # to files via line-range replacements.
  #
  # @return [Ollama::Tool] a tool definition for patching content in files
  def tool
    Tool.new(
      type: 'function',
      function: Tool::Function.new(
        name:,
        description: <<~EOT,
          Patch applicator – Proposes changes to an existing file by replacing
          specific line ranges. The tool applies these replacements in memory
          and launches an interactive diff session (e.g., vimdiff) between the
          original and the proposed version. Path of the file must be given,
          existing, and be allowed.

          Precision Hint: To identify exact line ranges for patching, first
          read the target file using `read_file` with `line_numbers: true`.

          CRITICAL: Line numbers may shift if the file was modified by a
          previous patch or manually in the editor. Before any attempt to
          patch, you should verify that the target lines still contain the
          expected content. To save tokens, you can read just the range around
          your target area using `read_file` with specific start/end lines.

          FRESHNESS CHECK: You MUST provide the current `mtime` and `line_count`
          of the file as returned by `read_file`. This ensures you are patching
          the most recent version of the file and prevents stale context errors.

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
              description: <<~EOT
                The path to the file to patch (must be within allowed directories)
              EOT
            ),
            edits: Tool::Function::Parameters::Property.new(
              type: 'array',
              description: <<~EOT,
                A list of edits. Each edit must contain start_line, end_line,
                and text.
              EOT
              items: Tool::Function::Parameters::Property.new(
                type: 'object',
                description: <<~EOT,
                  An edit block containing the line range and replacement text
                EOT
                properties: {
                  start_line: Tool::Function::Parameters::Property.new(
                    type: 'integer', description: '1-indexed start line'
                  ),
                  end_line: Tool::Function::Parameters::Property.new(
                    type: 'integer', description: '1-indexed end line'
                  ),
                  text: Tool::Function::Parameters::Property.new(
                    type: 'string', description: 'The replacement text'
                  ),
                },
              )
            ),
            mtime: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: 'The current modification time (ISO 8601) of the file from the latest `read_file` call.'
            ),
            line_count: Tool::Function::Parameters::Property.new(
              type: 'integer',
              description: 'The exact number of lines in the file from the latest `read_file` call.'
            ),
          },
          required: %w[path edits mtime line_count]
        )
      )
    )
  end

  # Processes a tool call to initiate a file patch review session.
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

    edits = args.edits or
      raise OllamaChat::ToolFunctionArgumentError,
      'require edits to patch file path with'
    edits = edits.map(&:to_h)

    path = args.path.full? or
      raise OllamaChat::ToolFunctionArgumentError,
      'require path to file to be patched'
    path = assert_valid_path(
      path,
      config.tools.functions.patch_file.allowed?,
      check: :file
    )

    # Freshness check to prevent stale context patching
    current_mtime = File.mtime(path).iso8601(0)
    current_lines = File.open(path) { _1.each_line.count }

    submitted_mtime = args.mtime
    submitted_lines = args.line_count

    if submitted_mtime != current_mtime
      raise OllamaChat::ToolFunctionArgumentError,
        "Stale context: File `#{path}` has been modified since your last read. "\
        "Expected mtime `#{current_mtime}`, got `#{submitted_mtime}`."
    end

    if submitted_lines != current_lines
      raise OllamaChat::ToolFunctionArgumentError,
        "Stale context: File `#{path}` line count mismatch. "\
        "Expected `#{current_lines}`, got `#{submitted_lines}`."
    end

    content = apply_edits(path, edits)
    result  = apply_patch(chat, path, content)

    message =
      if result[:success]
        "Successfully applied patch to #{path.to_s.inspect}."
      elsif result.key?(:patch_feedback)
        if msg = result.delete(:patch_feedback)
          <<~EOT
            User rejected the patch to file #{path.to_s.inspect} for reason:

            #{msg.inspect}
          EOT
        else
          "User accepted the patch to file #{path.to_s.inspect}."
        end
      else
        "Failed to apply patch to file #{path.to_s.inspect}."
      end

    (result | {
      path:    path.to_s,
      message: ,
    }).to_json
  rescue => e
    chat.log(:error, e, data: { tool: 'patch_file', path: path.to_s })
    {
      error:   e.class,
      success: false,
      message: "Failed to apply patch to file #{path.to_s.inspect}: #{e.message}",
      edits:   defined?(edits) ? edits : nil,
    }.to_json
  end

  private

  # Applies range-based edits in reverse order to a file's content.
  #
  # @param path [Pathname] The path to the existing file
  # @param edits [Array<Hash>] A list of edit objects containing :start_line,
  #   :end_line, and :text
  #
  # @return [String] The resulting content after all replacements
  def apply_edits(path, edits)
    lines = File.readlines(path, chomp: true)

    # 1. Validation & Overlap Check
    validate_and_check_overlaps!(edits, lines.size)

    # 2. Application (Reverse order to preserve indices)
    sorted_edits = edits.sort_by { -_1[:start_line] }

    sorted_edits.each do |edit|
      # Initial range boundaries
      s_idx = edit[:start_line] - 1
      e_idx = edit[:end_line] - 1

      lines[s_idx..e_idx] = [edit[:text]]
    end

    lines * ?\n
  end

  def validate_and_check_overlaps!(edits, file_size)
    edits.each_with_index do |e, i|
      e[:start_line] or raise OllamaChat::ToolFunctionArgumentError,
        "Edit ##{i + 1} is missing a start_line"
      e[:end_line] ||= e[:start_line]
      e[:text] or raise OllamaChat::ToolFunctionArgumentError,
        "Edit ##{i + 1} is missing its substiution text"
      if e[:start_line] < 1 || e[:end_line] > 1 && e[:end_line] > file_size || e[:start_line] > e[:end_line]
        raise OllamaChat::ToolFunctionArgumentError,
          "Invalid range for edit ##{i + 1}: lines #{e[:start_line]}-#{e[:end_line]} (File size: #{file_size})"
      end
    end

    # O(n**2) check is fine since 'edits' array is typically very small
    edits.each_with_index do |e1, i|
      edits[(i + 1)..-1].each do |e2|
        if e1[:start_line] <= e2[:end_line] && e2[:start_line] <= e1[:end_line]
          raise OllamaChat::ToolFunctionArgumentError,
            "Overlapping search blocks detected: lines "\
            "#{e1[:start_line]}-#{e1[:end_line]} and #{e2[:start_line]}-#{e2[:end_line]}"
        end
      end
    end
  end

  # Computes the MD5 digest of the file located at the given path.
  def digest(path)
    Digest::MD5.file(path)
  end

  # Launches an interactive diff session to apply proposed changes.
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
          if digest(path) == old_digest
            msg = chat.ask?(
              prompt: 'Give a reason for why the patch was rejected: (C-c ⇒ Accept.) '
            )
            result[:patch_feedback] = msg
          end
          if result[:patch_feedback]
            backup_path.delete
          else
            result[:backup_path] = backup_path
          end
          result[:success] &&= !result[:patch_feedback]
        end
      end
    end
    result
  end

  self
end.register
