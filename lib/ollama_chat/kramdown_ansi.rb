# A module that provides Kramdown::ANSI styling, parsing, and
# terminal table wrapping for OllamaChat.
#
# This module handles three concerns:
#
# * **Styling configuration** – sets up ANSI styles either from the
#   `KRAMDOWN_ANSI_OLLAMA_CHAT_STYLES` environment variable or from
#   built-in defaults.
# * **Markdown parsing** – converts raw markdown into ANSI-formatted
#   terminal output using the configured styles, with a fallback for
#   invalid encodings.
# * **Table wrapping** – computes per-column width budgets and wraps
#   cell content so that `Terminal::Table` output stays within a
#   configurable percentage of the terminal width.
#
# @example Configuring custom ANSI styles via environment variable
#   Set KRAMDOWN_ANSI_OLLAMA_CHAT_STYLES to a JSON object containing style
#   definitions for customizing markdown output formatting in the terminal.
module OllamaChat::KramdownANSI
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

  private

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

  # The kramdown_markdown_remove method strips markdown formatting, emoji,
  # ANSI escape sequences, and box-drawing characters from content, yielding
  # plain text suitable for TTS playback.
  #
  # @param content [ String, nil ] the content to strip.
  #   If nil or empty, returns an empty string.
  # @param markdown [ Boolean] if true (default), runs the full kramdown
  #   ANSI parse before stripping; if false, only removes emoji, ANSI,
  #   and box-drawing characters without markdown rendering.
  #
  # @return [ String ] the content with all markdown, ANSI, emoji, and
  #   box-drawing formatting removed, suitable for TTS playback
  def kramdown_markdown_remove(content, markdown: true)
    content.full? or return ''
    content = content.gsub(/\p{Extended_Pictographic}/, '').full? or return ''
    if markdown
      content = kramdown_ansi_parse(content).full? or return ''
    end
    content = OllamaChat::Utils::StripANSI.strip_ansi(content)
    # Remove box-drawing characters (U+2500..U+257F) that kramdown uses
    # for table borders/separators — TTS engines stammer on these.
    content.gsub(/[\u2500-\u257F]/, ' ')
           .gsub(/\s{2,}/, ' ')
           .strip
  end

  # Wraps the cells of a terminal table to fit within a terminal-width
  # budget.
  #
  # Terminal::Table sizes each column to its widest cell, so a single long
  # cell forces the whole table wider than the terminal. This computes a
  # per-column budget from the widest cell in each column across all rows,
  # then wraps each cell to it. Cells expressed as Hashes (e.g. colspan
  # rows) are passed through untouched.
  #
  # @param rows [Array<Array<String, Hash>>] the data rows to wrap
  # @param cols [Integer] the number of columns in the table
  # @param headings [Array<String>, nil] the heading row; when given it is
  #   measured for the budget and returned first, right-padded to each
  #   column's allocated width so Terminal::Table sizes columns to the
  #   full budget even when no data cell reaches it
  # @param percentage [Numeric] the percentage of terminal width to use for
  #   the total budget (default: 90)
  # @return [Array<Array<String, Hash>>] wrapped rows; the padded heading
  #   row is returned first when `headings` was supplied
  def wrap_table_rows(rows, cols, headings: nil, percentage: 90)
    all    = rows + (headings ? [headings] : [])
    budget = table_column_budgets(all, cols, percentage:)
    wrap_row = ->(row) {
      row.each_with_index.map { |cell, i|
        cell.is_a?(Hash) and next cell
        Kramdown::ANSI::Width.wrap(cell.to_s, length: budget[i], reflow: false)
      }
    }
    result = rows.map(&wrap_row)
    if headings
      padded = headings.each_with_index.map { |h, i|
        w = Kramdown::ANSI::Width.display_width(h)
        w < budget[i] ? h + ' ' * (budget[i] - w) : h
      }
      result.unshift(padded)
    end
    result
  end

  # Computes a per-column display-width budget for a terminal table.
  #
  # @param rows [Array<Array<String, Hash>>] the rows to measure (Hash cells
  #   are ignored)
  # @param cols [Integer] the number of columns
  # @param percentage [Numeric] the percentage of terminal width to use for
  #   the total budget (default: 90)
  # @return [Array<Integer>] the per-column width budget
  def table_column_budgets(rows, cols, percentage: 90)
    max_w = Array.new(cols, 0)
    rows.each do |row|
      row.each_with_index do |cell, i|
        cell.is_a?(Hash) and next
        w = cell.to_s.lines.map { |l| Kramdown::ANSI::Width.display_width(l) }.max || 0
        max_w[i] = [max_w[i], w].max
      end
    end
    total  = max_w.sum
    budget = Kramdown::ANSI::Width.width(percentage:) - (3 * cols + 1)
    return Array.new(cols, (budget.to_f / cols).to_i) if total.zero?
    if total <= budget
      extra = budget - total
      max_w.map { |w| w + ((w.to_f / total) * extra).floor }
    else
      share  = (budget.to_f / cols).to_i
      alloc  = max_w.map { |w| [w, share].min }
      unused = budget - alloc.sum
      return alloc if unused.zero?
      capped = (0...cols).to_a.select { |i| alloc[i] < max_w[i] }
      need   = capped.sum { |i| max_w[i] - alloc[i] }
      return alloc if need.zero?
      capped.each do |i|
        extra = ((max_w[i] - alloc[i]).to_f / need * unused).floor
        alloc[i] = [max_w[i], alloc[i] + extra].min
      end
      alloc
    end
  end
end
