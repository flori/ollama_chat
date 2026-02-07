# A module that provides common functionality for OllamaChat tools.
#
# This module serves as a base class for all tool implementations in the
# OllamaChat application, providing shared behavior and methods that tools can
# inherit from. It includes delegation to the tool name and registration
# functionality to integrate tools into the chat system's tool registry.
module OllamaChat::Tools::Concern
  extend Tins::Concern

  included do
    include Ollama

    implement :tool, :submodule
  end

  class_methods do
    # The register method registers the tool with the tools registry.
    # @return [ OllamaChat::Tools ] the current instance after registration
    def register
      OllamaChat::Tools.register(self)
    end

    # The register_name attribute accessor provides read and write access to
    # the register name of the tool.
    #
    # @return [ String ] the register name of the tool
    attr_accessor :register_name
  end

  # The name method returns the registered name of the tool.
  #
  # @return [String] the registered name of the tool instance
  def name
    self.class.register_name
  end

  # The valid_json? method returns a proc that validates JSON data from a
  # temporary file.
  #
  # @return [Proc] a proc that takes a temporary file and returns its JSON
  #   content or raises an error
  def valid_json?
    -> tmp {
      if data = tmp.read.full?
        JSON.parse(data)
        return data
      else
        raise JSON::ParserError, 'require JSON data'
      end
    }
  end

  # The to_hash method converts the tool to a hash representation.
  #
  # @return [ Hash ] a hash representation of the tool
  def to_hash
    tool.to_hash
  end
end
