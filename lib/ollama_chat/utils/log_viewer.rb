require 'json'
require 'tins/deep_transform'

module OllamaChat::Utils
  # Utilities for formatting, filtering, and displaying JSON log lines with
  # colorized output and regex-based path matching.
  module LogViewer
    # ANSI color utility for terminal output.
    Color = Term::ANSIColor

    # Maps standard logging levels to their corresponding ANSI colors.
    LEVEL_COLORS = {
      'debug' => :green,
      'info'  => :blue,
      'warn'  => :yellow,
      'error' => :red,
      'fatal' => :magenta
    }.freeze

    # Maps data types to their corresponding ANSI colors for structured payload # output.
    DATA_COLORS = {
      key:     :cyan,
      numeric: :green,
      boolean: :magenta,
      string:  :white
    }.freeze

    class << self
      # Formats a single JSON log line into a colorized, human-readable string.
      #
      # @param line [String] The raw JSON log line.
      # @param display_data [Boolean] Whether to include the structured data payload.
      # @param match [String, Array<String>, nil] Regex patterns to filter log entries by.
      # @return [String, nil] The formatted log line, or nil if filtered out.
      def format_line(line, display_data: true, match: nil)
        return nil if line.blank?

        event = JSON.parse(line)

        level  = (event['level'] || 'info').downcase
        time   = event['time'] || ''
        msg    = event['msg'] || ''
        data   = event['data'] || {}
        prog   = event['progname']

        matched?(event:, match:) or return

        color = LEVEL_COLORS[level] || :white
        header = '[%s] %s %s: %s' % [
          time,
          Color.bold { Color.color(color) { level.upcase } },
          prog,
          msg,
        ]

        payload = ""
        if display_data && data.is_a?(Hash) && data.any?
          colorized_data = data.deep_transform(
            key:   -> k { Color.cyan { k } },
            value: -> v {
              if s = v.ask_and_send(:to_str)
                JSON.parse(s) rescue v
              else
                v
              end
            }
          )
          payload = "\n" + format_hash(colorized_data)
        end

        header + payload
      rescue JSON::ParserError
        line unless match
      end

      private

      # Checks if a log event matches the provided regex patterns.
      #
      # @param event [Hash] The parsed JSON log event.
      # @param match [String, Array<String>, nil] The regex patterns to match against.
      # @return [Boolean] True if the event matches all provided patterns.
      def matched?(event:, match:)
        match or return true
        match.to_a.all? do |m|
          /\A(?<path>[^=]+)?(?:=(?<value_match>.*))?/ =~ m
          if path = path.split(?.).full?
            value = event
            while idx = path.shift
              case value
              when Array
                value = value[idx.to_i]
              when Hash
                value = value[idx]
              else
                break
              end
            end
            path.empty? or return
            if value_match
              value.ask_and_send(:match?, value_match)
            else
              value.present?
            end
          end
        end
      end

      # Recursively formats a hash into an indented, multi-line string.
      #
      # @param hash [Hash] The hash to format.
      # @param indent [Integer] The current indentation level.
      # @return [String] The formatted hash string.
      def format_hash(hash, indent = 2)
        ComplexConfig::Tree.convert(Color.bold { '🪵 data' }, hash)
      end
    end
  end
end
