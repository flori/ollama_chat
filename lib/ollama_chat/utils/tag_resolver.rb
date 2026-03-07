# YARD documentation for the TagResolver utility.
#
# The `OllamaChat::Utils::TagResolver` class provides a lightweight interface to query
# ctags-generated tag files.  It can resolve symbols by name, optional kind and
# directory constraints, returning an array of `TagResult` objects that include
# helpful metadata such as the line number where the symbol is defined.
class OllamaChat::Utils::TagResolver
  # Header fields used in a ctags tag entry. These are kept private to avoid
  # leaking implementation details outside the class.
  HEADERS = %i[ symbol filename regexp kind rest ]
  private_constant :HEADERS

  # Return a human‑readable description of a ctags tag kind. For example, `f`
  # (function) becomes "methods".
  #
  # @param [String] kind The single character kind identifier from the tags file.
  # @return [String]
  def self.kind_of(kind)
    ctags = ::OC::OLLAMA::CHAT::TOOLS::CTAGS_TOOL? or
      raise OllamaChat::ConfigMissingError,
      'need ctags tool path defined in %s' % (
        ::OC::OLLAMA::CHAT::TOOLS::CTAGS_TOOL!.env_var_name
      )
    @kinds ||= `#{ctags} --list-kinds=Ruby`.lines.map { _1.chomp.split(/\s+/, 2) }.to_h
    @kinds.fetch(kind, 'unknown')
  end

  # A lightweight struct representing a single tag entry. It extends the base
  # `Struct` with convenience methods for generating human‑readable messages and
  # JSON representations.
  class TagResult < Struct.new(*(HEADERS + %i[ linenumber ]))
    # @return [String] Human readable description of this tag result.
    def message
      "#{symbol} of kind #{kind} (#{kind_type}) at #{filename}:#{linenumber}"
    end

    # Resolve the full, human‑readable type for the `kind` field using
    # {OllamaChat::Utils::TagResolver.kind_of}.
    # @return [String]
    def kind_type
      OllamaChat::Utils::TagResolver.kind_of(kind)
    end

    # Convert to a hash suitable for JSON serialization. The `rest` field is
    # omitted because it contains raw ctags data that isn’t useful outside the
    # library.
    # @return [Hash]
    def as_json(*a)
      hash = super
      hash.delete('rest')
      hash | { 'message' => message, 'kind_type' => kind_type }
    end

    # JSON representation of this tag result. Delegates to `as_json`.
    # @return [String]
    def to_json(*a)
      as_json.to_json(*a)
    end
  end

  # Initialize a new resolver with the path or IO object pointing at a tags file.
  #
  # @param [IO, String] tags_file Path to the tags file or an already opened IO.
  def initialize(tags_file)
    tags_file.is_a?(IO) or tags_file = File.new(tags_file)
    @tags_file = tags_file
  end

  # Resolve a symbol in the tag file and return all matching results.
  #
  # The method scans each line of the tags file, filters by `symbol`, optional
  # `kind` and an optional directory prefix. For each match it calculates the
  # exact line number where the definition occurs using a regular expression.
  #
  # @param [String] symbol Name of the symbol to look up (required).
  # @param [String, nil] kind Optional tag kind filter (`f`, `v` …). If omitted
  #   all kinds are considered.
  # @param [String, nil] directory Only consider tags whose file path starts
  #   with this string.
  # @return [Array<TagResult>] All matching results sorted by the order they
  #   appear in the tags file.
  def resolve(symbol:, kind: nil, directory: nil)
    directory and directory = Pathname.new(directory).expand_path.to_path
    @tags_file.rewind
    results       = []
    @tags_file.each_line do |line|
      line.chomp!
      line =~ /\A([^\t]+)\t([^\t]+)\t\/\^([^\t]+)\$\/\;"\t([^\t])\t([^\t]+)$/ or next
      obj = TagResult.new(*$~.captures)
      next unless obj.symbol == symbol
      if kind
        obj.kind == kind or next
      end
      filename = Pathname.new(obj.filename).expand_path
      filename.exist? or next
      if directory
        filename.to_path.start_with?(directory) or next
      end
      regexp = Regexp.new(?^ + Regexp.quote(obj.regexp) + ?$)
      linenumber =
        begin
          File.open(filename) do |f|
            f.each_with_index.find { _1 =~ regexp and break 1 + _2 }
          end
        rescue
          1
        end
      obj.regexp     = regexp
      obj.filename   = filename.to_path
      obj.linenumber = linenumber
      results << obj
    rescue => e
      warn "Caught #{e.class}: #{e} for #{line}"
    end
    results
  end
end
