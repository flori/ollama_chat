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
#   selected = choose_entry(entries, prompt: 'Choose a fruit: %s')
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
  #   choose_entry(['entry1', 'entry2'], prompt: 'Choose an option: %s')
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
            -matcher.similar(n.ask_and_send_or_self(:value).to_s.downcase, /\b/)
          ]
        }.select { |_, s| s < 0 }.sort_by(&:last).map(&:first)
        matches.empty? and matches = entries
        matches
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

  # The choose_multi method presents a list of entries for multi-selection.
  #
  # Users toggle items with Tab and confirm with Enter, which returns
  # the full set of picked items as an Array. Ctrl-C aborts and returns nil.
  #
  # @param entries [Array] the list of entries to present to the user
  # @param prompt [String] the prompt message (default: 'Search? %s')
  # @param picked [ Array, nil ] items to pre-select (default: nil)
  # @param all [String, nil] sentinel entry that selects all items (default: nil)
  # @param none [String, nil] sentinel entry that clears all items (default: nil)
  # @param picked_icon [String] icon for selected items (default: '⚪')
  # @param unpicked_icon [String] icon for unselected items (default: '⚫')
  # @return [Array, nil] the picked items (excluding sentinels), or nil if aborted
  #
  # @example
  #   picked = choose_multi(
  #     entries,
  #     prompt: 'Toggle: %s [Tab=toggle, Enter=apply, C-c=abort]',
  #     picked: current_selection,
  #     all: '[ALL]'
  #   )
  def choose_multi(entries, prompt: 'Search? %s', picked: nil,
                    all: nil, none: nil,
                    picked_icon: '⚪', unpicked_icon: '⚫')
    state = current_search_state if dynamic_defined?(:current_search_state)
    search = Search.new(
      state:  ,
      prompt: ,
      multi:  true,
      picked: ,
      all:    ,
      none:   ,
      match:  -> answer {
        matcher = Amatch::PairDistance.new(answer.downcase)
        matches = entries.map { |n|
          [
            n,
            -matcher.similar(
              n.ask_and_send_or_self(:value).to_s.downcase, /\b/
            )
          ]
        }.select { |_, s| s < 0 }.sort_by(&:last).map(&:first)
        matches.empty? and matches = entries
        matches
      },
      query:  -> _answer, matches, selector, picked {
        matches.each_with_index.map { |m, i|
          mark   = picked[m] ? picked_icon : unpicked_icon
          cursor = i == selector ? " #{blue { ?⮕ }}" : '  '
          "#{cursor} #{mark} #{m}"
        } * ?\n
      },
      found:  -> _answer, matches, selector { matches[selector] },
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
