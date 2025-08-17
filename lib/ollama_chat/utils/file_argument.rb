# A module that provides functionality for handling file arguments and content
# retrieval.
#
# The FileArgument module offers methods to process either file paths or direct
# string content, determining whether the input represents a file that should
# be read or if it's already a string of content to be used directly. It also
# includes logic to handle default values when no valid input is provided.
#
# @example Retrieving file contents or using direct content
#   FileArgument.get_file_argument('path/to/file.txt')
#   # Returns the contents of the file if it exists
#
# @example Using a string as content
#   FileArgument.get_file_argument('direct content string')
#   # Returns the string itself
#
# @example Providing a default value
#   FileArgument.get_file_argument(nil, default: 'fallback content')
#   # Returns 'fallback content' when no valid input is given
module OllamaChat::Utils::FileArgument
  module_function

  # Returns the contents of a file or string, or a default value if neither is provided.
  #
  # @param [String] path_or_content The path to a file or a string containing
  #                 the content.
  #
  # @param [String] default The default value to return if no valid input is
  #                 given. Defaults to nil.
  #
  # @return [String] The contents of the file, the string, or the default value.
  #
  # @example Get the contents of a file
  #   get_file_argument('path/to/file')
  #
  # @example Use a string as content
  #   get_file_argument('string content')
  #
  # @example Return a default value if no valid input is given
  #   get_file_argument(nil, default: 'default content')
  def get_file_argument(path_or_content, default: nil)
    if path_or_content.present? && path_or_content.size < 2 ** 15 &&
        File.basename(path_or_content).size < 2 ** 8 &&
        File.exist?(path_or_content)
    then
      File.read(path_or_content)
    elsif path_or_content.present?
      path_or_content
    else
      default
    end
  end
end
