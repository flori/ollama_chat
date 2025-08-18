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
#   selected = OllamaChat::Utils::Chooser.choose(entries, prompt: 'Choose a fruit:')
#
# @example Returning immediately if only one entry exists
#   entries = ['single_option']
#   result = OllamaChat::Utils::Chooser.choose(entries, return_immediately: true)
#   # Returns 'single_option' directly without user interaction
module OllamaChat::Utils::Chooser
  class << self
    include SearchUI
    include Term::ANSIColor

    # The choose method presents a list of entries and prompts the user
    # for input, allowing them to select one entry based on their input.
    #
    # @param entries [Array] the list of entries to present to the user
    # @param prompt [String] the prompt message to display when asking for input (default: 'Search? %s')
    # @param return_immediately [Boolean] whether to immediately return the
    #        first entry if there is only one or nil when there is none (default: false)
    #
    # @return [Object] the selected entry, or nil if no entry was chosen
    #
    # @example
    #   choose(['entry1', 'entry2'], prompt: 'Choose an option:')
    def choose(entries, prompt: 'Search? %s', return_immediately: false)
      if return_immediately && entries.size <= 1
        return entries.first
      end
      entry = Search.new(
        prompt:,
        match: -> answer {
          matcher = Amatch::PairDistance.new(answer.downcase)
          matches = entries.map { |n| [ n, -matcher.similar(n.to_s.downcase) ] }.
            select { |_, s| s < 0 }.sort_by(&:last).map(&:first)
          matches.empty? and matches = entries
          matches.first(Tins::Terminal.lines - 1)
        },
        query: -> _answer, matches, selector {
          matches.each_with_index.map { |m, i|
            i == selector ? "#{blue{?⮕}} #{on_blue{m}}" : "  #{m.to_s}"
          } * ?\n
        },
        found: -> _answer, matches, selector {
          matches[selector]
        },
        output: STDOUT
      ).start
      if entry
        entry
      else
        print clear_screen, move_home
        nil
      end
    end
  end
end
