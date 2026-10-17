# Processes tool calls from Ollama responses: executes registered tools,
# collects results, and provides a drain interface for the chat loop to
# consume them as follow-up messages.
#
# This class encapsulates the full tool-call lifecycle that was previously
# split between {OllamaChat::FollowChat#handle_tool_calls} (execution)
# and {OllamaChat::ToolCalling#handle_tool_call_results?} (consumption).
class OllamaChat::ToolCallProcessor
  include Ollama::Handlers::Concern
  include Term::ANSIColor
  include OllamaChat::Feedback

  # @return [OllamaChat::Chat] the chat context
  attr_reader :chat

  # The accumulated tool results, keyed by tool name.
  #
  # @return [Hash{String => Array<String>}]
  attr_reader :results

  # @param chat [OllamaChat::Chat] the chat context
  # @param output [IO] the output stream for feedback (default: STDOUT)
  def initialize(chat:, output: STDOUT)
    super(output:)
    @chat = chat
    @results = Hash.new { |h, name| h[name] = [] }
  end

  # Processes tool calls from a response, executing each tool and
  # storing the result in the internal results hash.
  #
  # @param response [Ollama::Response] the parsed response
  def handle(response)
    return unless response.message.ask_and_send(:tool_calls)

    tools_used = {}

    response.message.tool_calls.each do |tool_call|
      name = tool_call.function.name
      if %r(.*[/:](?<new_name>.+)) =~ name
        msg = "Received namespaced tool call for #{name}, correcting to #{new_name}"
        chat.log(:warn, msg, data: { tool: name, new_name: })
        name = new_name
      end
      unless chat.tool_configured?(name)
        msg = "Error: Unconfigured tool named %s ignored => Skip.\n" % name
        @results[name] << msg
        chat.log(:error, msg, data: { tool: name, reason: :unconfigured })
        next
      end
      unless chat.tool_registered?(name)
        msg = "Error: Unregistered tool named %s ignored => Skip.\n" % name
        @results[name] << msg
        chat.log(:error, msg, data: { tool: name, reason: :unregistered })
        next
      end
      unless chat.tool_enabled?(name)
        msg = "Error: Disabled tool named %s ignored => Skip.\n" % name
        @results[name] << msg
        chat.log(:error, msg, data: { tool: name, reason: :disabled })
        next
      end
      feedback(?\n, output:)
      confirmed = :implicit
      resolve   = nil
      function  = JSON.pretty_generate(tool_call.function)
      chat.log(:info, "Tool call received", data: { tool: name, function: })
      if chat.tool_function(name).require_confirmation?
        feedback(
          ("I want to execute tool %s\n%s\n" % [ bold { name }, italic { function }, ]),
          type: :alarm
        )
        prompt  = '❓ Allow ✅[y]es / ⛔️[n]o / 📝[i]nstruct? '
        answer  = chat.confirm?(prompt:)&.to_s&.downcase
        resolve = 'You **MUST** ask the user for instructions on how to proceed!!!'
        case answer
        when 'y'
          confirmed = :explicit
        when 'n'
          confirmed = :denied
        else
          confirmed = :denied
          instr     = chat.ask?(prompt: '📝 Instructions: ')&.strip
          resolve   = instr.full? ||  resolve
        end
      else
        feedback(
          "Executing tool %s\n%s" % [ bold { name }, italic { function }, ]
        )
      end
      start  = Time.now
      result = nil
      case confirmed
      when :denied
        result = JSON(message: 'User denied confirmation!', resolve:)
        feedback(?\n)
        feedback(
          ("Execution of tool %s denied by user.\n\n" % [ bold { name } ]),
          type: :denied
        )
        chat.log(:warn, "Tool execution denied", data: { tool: name, reason: :denied })
      else
        symbol = confirmed == :implicit ? '☑️ ' : '✅'
        feedback(
          ("\n%s Execution of tool %s confirmed.\n\n" % [ symbol, bold { name } ])
        )
        result = OllamaChat::Tools.registered_tool(name, chat:).execute(tool_call)
        chat.log(:info, "Tool execution confirmed", data: { tool: name, confirmed: })
      end

      @results[name] << result
      data    = nil
      message = begin
                  data = JSON.parse(result)
                  chat.log(:info, "Tool result", data: { result: data })
                  data.to_hash['message'] if data.respond_to?(:to_hash)
                rescue
                  chat.log(:info, "Tool result", data: { result: })
                  nil
                end
      warn =
        begin
          !!data.ask_and_send(:[], 'error') || data.ask_and_send(:[], 'success') == false
        rescue
          false
        end

      es = OllamaChat::TokenEstimator.estimate(result.to_s)

      tools_used[name] = {
        message:,
        warn:     ,
        size:     es.bytes_formatted,
        tokens:   es.tokens_formatted,
        duration: Tins::Duration.new(Time.now - start).to_s,
      }
    end

    if tools_used.full?
      infobar.reset
      tools_used.each do |name, info|
        feedback_message =
          if info[:message]
            "\n%s %s\n\n" % [ info[:warn] ? '⚠️' : '💡', info[:message] ]
          end
        feedback(<<~EOT.strip)
          🔧 Tool functions #{name} returned result (#{info[:size]}/#{info[:tokens]} in #{info[:duration]}).
          #{feedback_message}
        EOT
        feedback(?\n)
        timeout = chat.tool_function(name).result_display_timeout?
        chat.confirm?(prompt: '⏎  Press any key to continue (%s). ', timeout:)
      end
    end
  end

  # Drains all accumulated results, yielding each entry to the block,
  # then clears the internal storage.
  #
  # @yield [index, tool_name, content] each result entry
  # @return [true, false] whether any results were present
  def drain(&block)
    @results.each do |tool_name, results|
      results.each_with_index { |content, index|
        block.(index, tool_name, content)
      }
    end.present?
  ensure
    @results.clear
  end

  # Clears all accumulated results without yielding them.
  def clear!
    @results.clear
  end
end
