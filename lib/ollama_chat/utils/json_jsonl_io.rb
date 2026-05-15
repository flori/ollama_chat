# A utility class for handling I/O operations for files in either JSON or JSONL format.
# The format is automatically determined by the file extension (.json or .jsonl).
class OllamaChat::Utils::JSONJSONLIO
  # Initializes a new JSONJSONLIO instance.
  #
  # @param filename [String, Pathname, nil] the path to the file.
  # @raise [ArgumentError] if the filename does not have a .json or .jsonl extension.
  def initialize(filename = nil)
    @filename = Pathname.new(filename).expand_path
    @type = case @filename.extname
    when '.json'  then :json
    when '.jsonl' then :jsonl
    else raise ArgumentError, "invalid filename #{@filename.to_path.inspect}"
    end
  end

  # @return [Pathname] the expanded filesystem path to the target file
  attr_reader :filename

  # Writes a collection to the file.
  #
  # @param opts [Hash] additional options passed to #write_io.
  def write(**opts)
    filename.open(?w) do |output|
      write_io(output:, **opts)
    end
  end

  # Performs the actual write operation to the provided IO object.
  #
  # @param output [IO] the IO object to write to.
  # @param collection [Enumerable] the collection of elements to write.
  def write_io(output:, collection:)
    case @type
    when :json
      output.puts JSON.dump(collection.to_a)
    when :jsonl
      collection.each do |element|
        output.puts JSON.dump(element)
      end
    end
  end

  # Reads the file and yields each element to the block.
  #
  # @param opts [Hash] additional options passed to #read_io.
  # @yield [Object] the parsed element.
  # @raise [ArgumentError] if no block is provided.
  def read(**opts, &block)
    block or return enum_for(__method__, **opts)
    filename.open(?r) do |input|
      read_io(input:, **opts, &block)
    end
  end

  # Performs the actual read operation from the provided IO object.
  #
  # @param input [IO] the IO object to read from.
  # @param json_transform [Proc] the transformation to apply to each element in a JSON file.
  # @param jsonl_transform [Proc] the transformation to apply to each line in a JSONL file.
  # @yield [Object] the transformed element.
  def read_io(input:, json_transform: Proc.id1, jsonl_transform: -> s { JSON.parse(s) }, &block)
    block or return enum_for(__method__, input:, json_transform:, jsonl_transform:)
    case @type
    when :json
      JSON.parse(input.read).map(&json_transform).each(&block)
    when :jsonl
      input.each_line do |line|
        block.(jsonl_transform.(line))
      end
    end
  end
end
