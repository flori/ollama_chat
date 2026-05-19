require 'amatch'
require 'search_ui'
require 'term/ansicolor'

# A module that provides interactive selection functionality using fuzzy
# matching and search capabilities.
#
# The Chooser module enables users to interactively select items from a list
# using a search interface with fuzzy matching. It leverages the Amatch library
# for similarity matching and SearchUI for the interactive display and
# selection experience.
#
# @example Using the chooser in an interactive menu
#   entries = ['apple', 'banana', 'cherry']
#   selected = choose_entry(entries, prompt: 'Choose a fruit:')
#
# @example Returning immediately if only one entry exists
#   entries = ['single_option']
#   result = choose_entry(entries, return_immediately: true)
#   # Returns 'single_option' directly without user interaction
module OllamaChat::Utils::Chooser
  include SearchUI
  include Tins::DynamicScope

  # @attribute [SearchUI::Search::State, nil] current_search_state Stores the
  #   search state (cursor position, query, etc.) of the most recent
  #   interactive search. This allows sequential calls to #choose to maintain
  #   user context and prevent the search from resetting.

  # The choose_entry method presents a list of entries and prompts the user
  # for input, allowing them to select one entry based on their input.
  #
  # @param entries [Array] the list of entries to present to the user
  # @param prompt [String] the prompt message to display when asking for input (default: 'Search? %s')
  # @param return_immediately [true, false] whether to immediately return the
  #        first entry if there is only one or nil when there is none (default: false)
  # @return [Object] the selected entry, or nil if no entry was chosen
  #
  # @example
  #   choose_entry(['entry1', 'entry2'], prompt: 'Choose an option:')
  def choose_entry(entries, prompt: 'Search? %s', return_immediately: false)
    if return_immediately && entries.size <= 1
      return entries.first
    end
    state = current_search_state if dynamic_defined?(:current_search_state)
    search = Search.new(
      state:,
      prompt:,
      match: -> answer {
        matcher = Amatch::PairDistance.new(answer.downcase)
        matches = entries.map { |n|
          [
            n,
            -matcher.similar(n.ask_and_send_or_self(:value).to_s.downcase)
          ]
        }.select { |_, s| s < 0 }.sort_by(&:last).map(&:first)
        matches.empty? and matches = entries
        matches.first(Tins::Terminal.lines - 1)
      },
      query: -> _answer, matches, selector {
        matches.each_with_index.map { |m, i|
          i == selector ? "#{blue{?⮕}} #{on_blue{m}}" : "  #{m}"
        } * ?\n
      },
      found: -> _answer, matches, selector {
        matches[selector]
      },
      output: STDOUT
    )
    entry                     = search.start
    self.current_search_state = search.state if dynamic_defined?(:current_search_state)
    if entry
      entry
    else
      print clear_screen, move_home
      nil
    end
  end

  # Wraps a block of code to provide a fresh search state for sequential
  # interactive selections.
  #
  # This method resets the `current_search_state` to nil and then yields.
  # Any calls to #choose_entry within the block will share and maintain
  # the same search state, ensuring that the cursor and query are
  # preserved between iterations of a loop, but are reset once the
  # block is exited.
  #
  # @yield [block] the sequence of interactive selections to perform
  # @return [Object] the result of the yielded block
  def choose_with_state
    dynamic_scope do
      self.current_search_state = nil
      yield
    end
  end
end
