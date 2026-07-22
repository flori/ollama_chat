# A module that provides interactive selection and configuration functionality
# for OllamaChat.
#
# The Dialog module encapsulates various helper methods for choosing models,
# system prompts, document policies, and voices, as well as displaying
# information and managing chat sessions. It leverages user interaction
# components like choosers and prompts to enable dynamic configuration during
# runtime.
module OllamaChat::Dialog
  # The ask? method prompts the user with a question and returns their input.
  #
  # @param prompt [ String ] the message to display to the user
  #
  # @return [ String ] the user's response with trailing newline removed
  def ask?(prompt:, prefill: nil)
    if prefill
      old_pre_input_hook = Reline.pre_input_hook
      Reline.pre_input_hook = -> { Reline.insert_text prefill.to_s }
    end
    Reline.readline(prompt, true)&.chomp
  rescue Interrupt
    return nil
  ensure
    prefill and Reline.pre_input_hook = old_pre_input_hook
  end

  # The confirm? method displays a prompt and reads a single character input
  # from the user in raw mode, then returns that character. This is best used
  # for confirmation prompts.
  #
  # @param prompt   [String]  the prompt to display to the user
  # @param timeout  [Integer, nil] optional timeout in seconds; if nil, the
  #   method blocks until input, if 0 the method immediately returns the default
  #   value.
  # @param default  [Object, nil]  value returned when the timeout expires
  #   (defaults to `nil`)
  # @param yes      [Object, nil]  value that is considered a positive response
  # @param output   [IO]  the IO object to write the prompt to
  #
  # @return [Object] the character entered by the user, or the `default` value
  #   if a timeout occurs
  def confirm?(prompt:, timeout: nil, default: nil, yes: nil, output: STDOUT)
    return default if timeout&.zero?
    if prompt.include?('%s')
      prompt = prompt % (timeout ? ('timeout in %us' % timeout) : 'no timeout')
    end
    print prompt
    system 'stty raw'
    keypress = nil
    c = if timeout
          keypress = !!IO.select([ STDIN ], nil, nil, timeout)
          keypress ? STDIN.getc : nil
        else
          keypress = true
          STDIN.getc
        end
    system 'stty cooked'
    answer = c || default
    case
    when yes.nil?
      if keypress
        output.puts "⌨️ #{answer}"
      else
        output.puts "⌛️ #{answer}"
      end
      answer
    when answer =~ yes
      if keypress
        output.puts "✅ #{answer}"
      else
        output.puts "☑️  #{answer}"
      end
      answer
    else
      if keypress
        output.puts "🚫 #{answer}"
      else
        output.puts "⌛️ #{answer}"
      end
      nil
    end
  end

  private

  # The choose_file_set method aggregates all files matching the given patterns
  # by repeatedly invoking choose_filename and collecting their expanded paths
  # into a Set.
  #
  # @param patterns [ Array<String> ] optional glob patterns to match; defaults
  #   to '**/*'.
  #
  # @return [ Set<Pathname> ] a set of expanded Pathname objects for each
  #   selected file.
  #
  def choose_file_set(patterns)
    patterns ||= '**/*'
    patterns = Array(patterns).map { Pathname.new(_1).expand_path }
    files = Set[]
    choose_with_state do
      while filename = choose_filename(patterns, chosen: files)
        files << filename.expand_path
      end
    end
    files
  end

  # The connect_message method displays a connection status message.
  #
  # @param model [String] the model name to connect to
  # @param base_url [String] the base URL of the connection
  def connect_message(model, base_url)
    msg = "Connecting to #{model}@#{base_url} now…"
    log(:info, msg, data: { model:, base_url: })
    STDOUT.puts green { msg }
  end

  # The change_voice method allows the user to select a voice from a list of
  # available options. It uses the chooser to present the options and sets the
  # selected voice as the current voice.
  #
  # @return [ String ] the full name of the chosen voice
  def change_voice
    voices.choose
  end

  # The message_list method creates and returns a new MessageList instance
  # initialized with the current object as its argument.
  #
  # @return [ MessageList ] a new MessageList object
  def message_list
    MessageList.new(self)
  end

  # Parses and executes a command using Tins::GO.
  #
  # @param s [String] The Tins::GO option pattern string where each character
  #   represents an option, and ':' indicates the option requires an argument.
  # @param opt [Object] The arguments to be parsed. This object is converted
  #   to a string, stripped of whitespace, and split into an array of strings.
  # @return [Hash{String => Object}] A hash mapping option names to their values.
  def go_command(s, opt, defaults: {})
    Tins::GO.go(s, opt.to_s.strip.split(/\s+/), defaults:)
  end
end
