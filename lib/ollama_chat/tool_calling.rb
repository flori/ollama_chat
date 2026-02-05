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
  def tools
    @enabled_tools.map { OllamaChat::Tools.registered[it]&.to_hash }.compact
  end

  # The configured_tools method returns an array of tool names configured for
  # the chat session.
  #
  # This method retrieves the list of available tools from the configuration
  # and returns them as a sorted array of strings. It handles cases where the
  # tools configuration might be nil or empty by returning an empty array.
  #
  # @return [Array<String>] a sorted array of tool names configured for the
  #   chat session
  def configured_tools
    Array(config.tools&.attribute_names&.map(&:to_s)).sort
  end

  # The tool_call_results reader returns the tools' results for the
  # chat session if any.
  #
  # @return [ Hash ] a hash containing the registered tool results
  attr_reader :tool_call_results

  # The list_tools method displays the sorted list of enabled tools.
  #
  # This method outputs to standard output the alphabetically sorted list of
  # tool names that are currently enabled in the chat session.
  def list_tools
    puts @enabled_tools.sort
  end

  # The enable_tool method allows the user to select and enable a tool from a
  # list of available tools.
  #
  # This method presents a menu of tools that can be enabled, excluding those
  # that are already enabled. It uses the chooser to display the available
  # tools and handles the user's selection by adding the chosen tool to the
  # list of enabled tools and sorting the list.
  def enable_tool
    select_tools = configured_tools - @enabled_tools
    select_tools += [ '[EXIT]' ]
    case chosen = OllamaChat::Utils::Chooser.choose(select_tools)
    when '[EXIT]', nil
      STDOUT.puts "Exiting chooser."
      return
    when *select_tools
      @enabled_tools << chosen
      @enabled_tools.sort!
      puts "Enabled tool %s" % bold(chosen)
    end
  end

  # The disable_tool method allows the user to select and disable a tool from a
  # list of enabled tools.
  #
  # This method presents a menu of currently enabled tools to the user,
  # allowing them to choose which tool to disable. It uses the chooser to
  # display the available tools and handles the user's selection by removing
  # the chosen tool from the list of enabled tools and sorting the list
  # afterwards.
  def disable_tool
    select_tools = @enabled_tools
    select_tools += [ '[EXIT]' ]
    case chosen = OllamaChat::Utils::Chooser.choose(select_tools)
    when '[EXIT]', nil
      STDOUT.puts "Exiting chooser."
      return
    when *select_tools
      @enabled_tools.delete chosen
      puts "Disabled tool %s" % bold(chosen)
    end
  end

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
