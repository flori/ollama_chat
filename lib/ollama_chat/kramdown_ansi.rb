# A module that provides Kramdown::ANSI styling configuration and parsing
# functionality for OllamaChat.
#
# This module handles the setup and application of ANSI styles for markdown
# rendering, allowing for customizable terminal output formatting. It manages
# the configuration of ANSI styles either from environment variables or falls
# back to default settings, and provides methods to parse content with the
# configured styling.
#
# @example Configuring custom ANSI styles via environment variable
#   Set KRAMDOWN_ANSI_OLLAMA_CHAT_STYLES to a JSON object containing style
#   definitions for customizing markdown output formatting in the terminal.
module OllamaChat::KramdownANSI
  # The configure_kramdown_ansi_styles method sets up ANSI styling for
  # Kramdown::ANSI output by checking for specific environment variables and
  # falling back to default styles.
  #
  # @return [ Hash ] a hash of ANSI styles configured either from environment
  #   variables or using default settings
  def configure_kramdown_ansi_styles
    if json = OC::KRAMDOWN_ANSI_OLLAMA_CHAT_STYLES?
      Kramdown::ANSI::Styles.from_json(json).ansi_styles
    else
      Kramdown::ANSI::Styles.new.ansi_styles
    end
  end

  # The kramdown_ansi_parse method processes content using Kramdown::ANSI with
  # custom ANSI styles.
  #
  # This method takes raw content and converts it into formatted ANSI output by
  # applying the instance's configured ANSI styles. It is used to render
  # content with appropriate terminal formatting based on the application's
  # styling configuration.
  #
  # @param content [ String, nil ] the raw content to be parsed and formatted.
  #   If nil, returns an empty string.
  #
  # @return [ String ] the content formatted with ANSI escape sequences
  #   according to the configured styles
  def kramdown_ansi_parse(content)
    retried ||= false
    content.nil? and return ''
    Kramdown::ANSI.parse(content, ansi_styles: @kramdown_ansi_styles)
  rescue Encoding::UndefinedConversionError
    return content if retried
    retried = true
    content = content.encode(invalid: :replace)
    retry
  end

  # The kramdown_markdown_remove method strips all markdown formatting from
  # content by first rendering it to ANSI and then removing escape sequences
  # and box-drawing characters, yielding plain text suitable for TTS.
  #
  # @param content [ String, nil ] the markdown content to strip.
  #   If nil, returns an empty string.
  #
  # @return [ String ] the content with all markdown, ANSI, and box-drawing
  #   formatting removed, suitable for TTS playback
  def kramdown_markdown_remove(content)
    content.full? or return ''
    content = kramdown_ansi_parse(content).full? or return ''
    content = OllamaChat::Utils::StripANSI.strip_ansi(content)
    # Remove box-drawing characters (U+2500..U+257F) that kramdown uses
    # for table borders/separators — TTS engines stammer on these.
    content.gsub(/[\u2500-\u257F]/, ' ')
           .gsub(/\s{2,}/, ' ')
           .strip
  end
end
