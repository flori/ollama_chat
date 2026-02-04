# A module that provides tool calling functionality for OllamaChat.
#
# The ToolCalling module encapsulates methods for managing and processing tool
# calls within the chat application. It handles the registration and execution
# of tools that can be invoked during conversations, allowing the chat to
# interact with external systems or perform specialized tasks beyond simple
# text generation.
module OllamaChat::ToolCalling
  # The tools reader returns the registered tools for the chat session.
  #
  # @return [ Hash ] a hash containing the registered tools
  attr_reader :tools

  # The tool_call_results reader returns the tools' results for the
  # chat session if any.
  #
  # @return [ Hash ] a hash containing the registered tool results
  attr_reader :tool_call_results

  private

  # The handle_tool_call_results? method processes and returns results from
  # tool calls.
  #
  # This method checks if there are any pending tool call results and formats
  # them into a string message. It clears the tool call results after
  # processing.
  #
  # @return [ String, nil ] a formatted string containing tool call results or
  #   nil if no results exist
  def handle_tool_call_results?
    @tool_call_results.present? or return
    content = @tool_call_results.map do |name, result|
      "Tool %s returned %s" % [ name, result ]
    end.join(?\n)
    @tool_call_results.clear
    content
  end
end
