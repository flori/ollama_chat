require 'io/console'

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
    speaker = speak(prompt, background: 10)
    Reline.readline(prompt, true)&.chomp

  rescue Interrupt
    return nil
  ensure
    speaker&.cancel_speaking
    prefill and Reline.pre_input_hook = old_pre_input_hook
  end

  # The confirm? method displays a prompt and reads a **single keypress**
  # from the user in raw mode (no Enter required), returning that character.
  # Unlike {#ask?}, it does not go through Reline, so it never pollutes the
  # command history — making it the right tool for confirmation gates *and*
  # terse single-key selections such as `[v]iew` / `[c]lear` menus.
  #
  # The returned value depends on whether a positive-response matcher (`yes`)
  # is supplied:
  #
  # - `yes: nil` (default) — the raw keypress is returned verbatim so the
  #   caller can dispatch on it (e.g. `case key; when /\Av/i; ...`); on
  #   timeout the `default` value is returned, and on interrupt (Ctrl-C)
  #   `nil` is returned.
  # - `yes: <Regexp/Object>` — the keypress is returned only when it
  #   satisfies `yes === keypress` (e.g. `yes: /\Ay/i`); any other keypress,
  #   or an interrupt, yields `nil`.
  #
  # @param prompt   [String]  the prompt to display to the user
  # @param timeout  [Integer, nil] optional timeout in seconds; if nil, the
  #   method blocks until input, if 0 it immediately returns the `default`
  #   value without waiting.
  # @param default  [Object, nil]  value returned when the timeout expires
  #   (defaults to `nil`)
  # @param yes      [Object, nil]  matcher (`#===`) that defines a positive
  #   response; when `nil` the raw keypress is returned for the caller to
  #   interpret (default: `nil`)
  # @param output   [IO]  the IO object to write the prompt and the answer to
  #
  # @return [Object, nil] see the dispatch rules above: the keypress (or
  #   `default` on timeout / `nil` on interrupt) when `yes:` is nil, otherwise
  #   the keypress only if it matches `yes`, else `nil`.
  def confirm?(prompt:, timeout: nil, default: nil, yes: nil, output: STDOUT)
    return default if timeout&.zero?
    if prompt.include?('%s')
      prompt = prompt % (timeout ? ('timeout in %us' % timeout) : 'no timeout')
    end
    speaker = speak(prompt, background: 10) if timeout.nil?
    output.print prompt
    min    = 1
    time   = 0
    if timeout
      min  = 0
      time = timeout
    end
    exceptions = [ (IRB::Abort if defined? IRB), Interrupt ].compact
    begin
      keypress = STDIN.raw(min:, time:, intr: true) do |io|
        io.getc
      end
    rescue *exceptions
      output.puts "\u274C"
      return
    end
    answer = keypress || default
    case
    when yes.nil?
      if keypress
        output.puts "\u2328 #{answer}"
      else
        output.puts "\u231B #{answer}"
      end
      answer
    when answer =~ yes
      if keypress
        output.puts "\u2705 #{answer}"
      else
        output.puts "\u2611 #{answer}"
      end
      answer
    else
      if keypress
        output.puts "\u{1F6AB} #{answer}"
      else
        output.puts "\u231B #{answer}"
      end
      nil
    end
  ensure
    speaker&.cancel_speaking
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

  # Displays an info-level feedback message indicating that a connection
  # to an Ollama server is being established.
  #
  # @param base_url [URI, String] the target Ollama server URL
  # @param prefix [String] an optional label prepended to "ollama" to
  #   distinguish the connection type, e.g. `"embedding "` for a dedicated
  #   embedding host (default: `""`)
  def connect_message(base_url:, prefix: '')
    feedback green { "Connecting to #{prefix}ollama #{base_url.to_s.inspect}…" }, type: :info
  end

  # Displays a success-level feedback message confirming that a
  # connection was established. Counterpart to {#connect_message}.
  def connect_message_done
    feedback green { "Done." }, type: :success
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

  # Prompts the user for a filename with history support.
  #
  # @param action [String, nil] an optional action descriptor appended to the
  #   prompt, e.g. "for summarization" ("❓ Enter filename for summarization…")
  #
  # @return [Pathname, nil] the user-supplied filename as a Pathname, or nil
  #   if the user cancels (C-c) or provides empty input
  def ask_for_filename?(action: nil)
    action and action = " #{action}"
    switch_history(:filename) {
      ask?(prompt: "❓ Enter filename#{action}, C-c ⇒ cancel: ")
    }.full? { Pathname.new(_1) }
  end

  # Checks whether a file can be written, prompting for overwrite
  # confirmation if the file already exists.
  #
  # @param filename [Pathname] the target file to check
  #
  # @return [Boolean] `true` if the file does not exist or the user confirms
  #   overwriting; `false` if the file exists and the user declines
  def should_overwrite?(filename)
    if filename.exist? && !confirm?(
        prompt: "🔔 File #{filename.to_s.inspect} already exists, overwrite? (y/n) ",
        yes: /\Ay/i
      )
    then
      feedback("File not written!", type: :warn)
      false
    else
      true
    end
  end
end
