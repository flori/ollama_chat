# A module that provides tool calling functionality for OllamaChat.
#
# The ToolCalling module encapsulates methods for managing and processing tool
# calls within the chat application. It handles the registration and execution
# of tools that can be invoked during conversations, allowing the chat to
# interact with external systems or perform specialized tasks beyond simple
# text generation.
module OllamaChat::ToolCalling
  # Checks whether a tool is configured in the chat configuration.
  #
  # @param [String] name the name of the tool
  # @return [true, false] true if the tool is configured
  def tool_configured?(name)
    config.tools.functions.attribute_set?(name)
  end

  # The tool_function method retrieves a tool configuration by name from the
  # chat's configuration.
  #
  # @param name [String] the name of the tool to retrieve
  # @return [ ComplexConfig::Settings ] the tool configuration object
  #   corresponding to the given name
  def tool_function(name)
    config.tools.functions[name]
  end

  # Determines whether a tool has been registered in the tool registry.
  #
  # @param [String] name the name of the tool
  # @return [true, false] true if the tool is registered
  def tool_registered?(name)
    OllamaChat::Tools.registered?(name)
  end

  # Provides access to the list of enabled tools for the chat session.
  #
  # @return [Array<String>] an Array containing the enabled tools
  def enabled_tools
    enabled = session.tools_default_enabled
    config.tools.functions.attribute_names.select {
      enabled[_1.to_s]
    }.map(&:to_s)
  end

  # Checks if a tool is currently enabled for the chat session.
  #
  # @param [String] name the name of the tool
  # @return [true, false] true if the tool is enabled
  def tool_enabled?(name)
    enabled_tools.member?(name.to_s)
  end

  # The tools reader returns the registered tools for the chat session.
  #
  # @return [ Hash ] a hash containing the registered tools
  def tools
    tools_support.off? and return []
    enabled_tools.filter_map {
      OllamaChat::Tools.registered_tool(_1, chat: self)&.to_hash
    }
  end

  # The default_enabled_tools method returns an array of tool names that are
  # configured as default tools.
  #
  # This method iterates through the configured tools and collects those that
  # are registered and have the default flag set to true. Unregistered tools
  # are skipped with a warning message.
  #
  # @return [Array<String>] a sorted array of tool names that are configured as
  #   default tools
  def default_enabled_tools
    result = []
    config.tools.functions.each { |n, v|
      if tool_registered?(n)
        result << n.to_s if v.default
      else
        feedback("Skipping configuration for unregistered tool %s" % bold { n }, type: :warn)
      end
    }
    result
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
    Array(config.tools&.functions&.attribute_names&.map(&:to_s)).sort
  end

  # The choose_tools method opens an interactive multi-select picker showing
  # all configured tools with their current enabled/disabled state and
  # confirmation requirement. The user toggles tools with Tab and
  # applies changes with Enter.
  #
  # @return [nil]
  def choose_tools
    unless tools_support.on?
      return feedback(
        'Tools are globally disabled. Use /tools on first.', type: :warn
      )
    end
    entries = configured_tools.map do |tool|
      marker = tool_function(tool).require_confirmation? ? '❔' : '⭕'
      SearchUI::Wrapper.new(tool, display: "#{marker} #{tool}")
    end
    picked = entries.select { |e| enabled_tools.include?(e.value) }
    result = choose_multi(
      entries,
      prompt: 'Choose tools: %s [Tab=toggle, Enter=apply, C-c=abort]',
      picked:,
      picked_icon:   '✅',
      unpicked_icon: '⛔'
    ) or return feedback('Aborted.')

    result     = result.map(&:value)
    to_enable  = result - enabled_tools
    to_disable = enabled_tools - result

    to_enable.each  { |t| session.tools_default_enabled[t] = true }
    to_disable.each { |t| session.tools_default_enabled[t] = false }

    unless (to_enable + to_disable).empty?
      unless session.save
        feedback('Could not save session.', type: :warn)
        confirm?(prompt: "\n\u23CE  Press any key to continue (%s). ", timeout: 3)
      else
        feedback(
          "Enabled: %s | Disabled: %s" %
            [ to_enable.join(', ').inspect, to_disable.join(', ').inspect ]
        )
      end
    end
  end
end
