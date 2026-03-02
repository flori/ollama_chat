# Module for handling pager functionality in the chat application.
#
# Provides methods to display long-form content using pagers like 'less' or
# 'more', automatically handling terminal line capacity and improving the user
# experience when viewing large amounts of output.
#
# This module is used throughout the application to paginate long messages,
# configuration outputs, and other text content that might not fit in the
# current terminal window.
module OllamaChat::Pager
  # The use_pager method wraps the given block with a pager context.
  # If the output would exceed the terminal's line capacity, it pipes the content
  # through an appropriate pager command (like 'less' or 'more').
  #
  # @yield A block that yields an IO object to write output to
  # @yieldparam [IO] the IO object to write to
  def use_pager
    command       = determine_pager_command
    output_buffer = StringIO.new
    yield output_buffer
    messages = output_buffer.string
    Kramdown::ANSI::Pager.pager(command:, lines: messages.count(?\n)) do |output|
      output.puts messages
    end
  end

  private

  # The determine_pager_command method identifies an appropriate pager command
  # for displaying content.
  # It first checks for a default pager specified by the PAGER environment variable.
  # If no default is found, it attempts to locate 'less' or 'more' in the
  # system PATH as fallback options.
  # The method returns the selected pager command, ensuring it includes the
  # '-r' flag for proper handling of raw control characters when a fallback
  # pager is used.
  def determine_pager_command
    OC::PAGER?
  end
end
