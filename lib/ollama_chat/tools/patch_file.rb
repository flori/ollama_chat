# A tool for proposing changes to a file through an interactive diff session.
#
# This tool allows the assistant to propose specific line-range replacements.
# The resulting content is written to a temporary file and opened in a diff
# tool (e.g., vimdiff) alongside the original file, enabling the user to
# selectively apply changes.
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

          FRESHNESS CHECK: You MUST provide the current `checksum` (8 hex
          digits long CRC32) of the file as returned by `read_file`. This
          ensures you are patching the most recent version of the file and
          prevents stale context errors.

          IMPORTANT: The checksum is only returned by `read_file` when the
          entire file is read with `line_numbers: true` (no start_line or
          end_line specified). This is deliberate — you must have read the
          complete file with line numbers before patching, ensuring you have
          full context of the file's structure.
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
            checksum: Tool::Function::Parameters::Property.new(
              type: 'string',
              description: <<~EOT
                The CRC32 checksum of the file from the latest `read_file` call
                (8 hex digits long).
              EOT
            ),
          },
          required: %w[path edits checksum]
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
    edits.is_a?(Array) or
      raise OllamaChat::ToolFunctionArgumentError,
      'edits needs to be an array of edits'
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
    content, current_checksum = File.open(path, 'r') { |file|
      [ file.read.tap { file.rewind }, '%08x' % Zlib.crc32(file) ]
    }

    if args.checksum != current_checksum
      raise OllamaChat::ToolFunctionArgumentError,
        "Stale context: File `#{path}` has been modified since your last read. " \
        "Unexpected checksum `#{args.checksum}`, I cannot patch!"
    end

    # We use the content we just read for the patch, as it's verified fresh
    patched_content = apply_edits(content, edits)
    result  = apply_patch(chat, path, patched_content)

    chat.log(:info, "File patched", data: {
      tool: name, path: path.to_s, success: result[:success], edits_count: edits.size
    })

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
          <<~EOT
            User accepted the patch to file #{path.to_s.inspect}. **NEVER** call
            the tool function with this patch again, as it has already been
            applied successfully!
          EOT
        end
      else
        "Failed to apply patch to file #{path.to_s.inspect}."
      end

    mtime, checksum = File.open(path, 'rb') {
      [ _1.mtime.iso8601(0), '%08x' % Zlib.crc32(_1) ]
    }

    (result | {
      path:     path.to_s,
      message:  message,
      mtime:    ,
      checksum: ,
    }).to_json

  rescue => e
    chat.log(:error, e, data: { tool: name, path: path.to_s })
    {
      error:     e.class,
      success:   false,
      message:   "Failed to apply patch to file #{path.to_s.inspect}: #{e.message}",
      edits:     defined?(edits) ? edits : nil,
    }.compact.to_json
  end

  private

  # Applies range-based edits in reverse order to a file's content.
  #
  # @param content [String] The raw content of the file
  # @param edits [Array<Hash>] A list of edit objects containing :start_line,
  #   :end_line, and :text
  #
  # @return [String] The resulting content after all replacements
  def apply_edits(content, edits)
    lines = content.lines(chomp: true)

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

  # Validates the provided edits and checks for overlapping line ranges.
  #
  # @param edits [Array<Hash>] The edits to validate
  # @param file_size [Integer] The total number of lines in the file
  # @raise [OllamaChat::ToolFunctionArgumentError] if edits are invalid or
  #   overlapping
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
  #
  # @param path [Pathname] The path to the file
  # @return [String] The MD5 digest of the file
  def digest(path)
    Digest::MD5.file(path)
  end

  # Launches an interactive diff session to apply proposed changes.
  #
  # @param chat [OllamaChat::Chat] The chat instance
  # @param path [Pathname] The path to the file being patched
  # @param content [String] The proposed patched content
  # @return [Hash] The result of the patch application
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
