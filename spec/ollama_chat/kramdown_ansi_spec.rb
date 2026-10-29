describe OllamaChat::KramdownANSI do
  let :argv do
    chat_default_config
  end

  let :chat do
    OllamaChat::Chat.new(argv:).expose
  end

  connect_to_ollama_server

  describe '#configure_kramdown_ansi_styles', protect_env: true do
    it 'can be configured via env var' do
      const_conf_as(
        'OC::KRAMDOWN_ANSI_OLLAMA_CHAT_STYLES' => '{"foo":"bar"}'
      )
      styles = { bold: '1' }
      expect(Kramdown::ANSI::Styles).to receive(:from_json).
        with('{"foo":"bar"}').
        and_return(double(ansi_styles: styles))
      expect(chat.configure_kramdown_ansi_styles).to eq(styles)
    end

    it 'has a default configuration' do
      const_conf_as(
        'OC::KRAMDOWN_ANSI_OLLAMA_CHAT_STYLES' => nil
      )
      expect(chat.configure_kramdown_ansi_styles).to be_a(Hash)
    end
  end

  describe '#kramdown_ansi_parse' do
    it 'can parse markdown' do
      content = "# Header\n\nParagraph text"
      result = chat.kramdown_ansi_parse(content)

      expect(result).to be_a(String)
    end

    it 'handles empty string correctly' do
      expect(chat.kramdown_ansi_parse('')).to eq ''
    end

    it 'handles nil correctly' do
      expect(chat.kramdown_ansi_parse(nil)).to eq ''
    end
  end

  describe '#kramdown_markdown_remove' do
    it 'returns empty string for nil' do
      expect(chat.kramdown_markdown_remove(nil)).to eq ''
    end

    it 'returns empty string for empty string' do
      expect(chat.kramdown_markdown_remove('')).to eq ''
    end

    it 'removes table separator rows' do
      input  = "| Name | Age |\n|------|-----|\n|Foo | 42|\n"
      result = chat.kramdown_markdown_remove(input)
      expect(result).not_to include('-')
    end

    it 'replaces box-drawing characters from rendered tables' do
      input = "| Name | Age |\n|------|-----|\n| Foo  | 42   |"
      result = chat.kramdown_markdown_remove(input)
      expect(result).not_to include("│")
      expect(result).not_to include("╭")
      expect(result).to include('Name')
      expect(result).to include('Foo')
    end

    it 'preserves ASCII pipes in non-table lines (code, formulas)' do
      input = 'look at this shell command `ls | grep foo`'
      result = chat.kramdown_markdown_remove(input)
      expect(result).to include('|')
    end

    it 'collapses multiple spaces in table rows' do
      input = '|  Name  |  Age  |'
      result = chat.kramdown_markdown_remove(input)
      expect(result).not_to match(/ {2,}/)
    end

    it 'strips bold and other markdown formatting' do
      input = '**hello** world'
      result = chat.kramdown_markdown_remove(input)
      expect(result).to eq 'hello world'
    end

    it 'removes emoji before processing' do
      input = 'what is this? 🍓'
      result = chat.kramdown_markdown_remove(input)
      expect(result).to eq 'what is this?'
    end

    it 'returns empty string when only emoji are present' do
      expect(chat.kramdown_markdown_remove('🍓✨')).to eq ''
    end

    it 'skips kramdown parse when markdown: false' do
      input = '**bold** text'
      expect(chat).not_to receive(:kramdown_ansi_parse)
      result = chat.kramdown_markdown_remove(input, markdown: false)
      expect(result).to include('**bold**')
    end
  end

  describe '#wrap_table_rows' do
    it 'wraps long cells to fit within terminal budget' do
      long_text = 'word ' * 50
      rows      = [[ long_text, 'short' ]]
      result    = chat.wrap_table_rows(rows, 2)
      expect(result[0][0]).to include("\n")
    end

    it 'passes Hash cells (colspan) through untouched' do
      rows   = [[ { value: 'category', colspan: 4 } ]]
      result = chat.wrap_table_rows(rows, 4)
      expect(result).to eq(rows)
    end

    it 'returns wrapped headings first when supplied' do
      rows   = [[ 'a', 'b' ]]
      result = chat.wrap_table_rows(rows, 2, headings: ['H1', 'H2'])
      expect(result.first.map(&:strip)).to eq(['H1', 'H2'])
      expect(result.size).to eq(2)
    end

    it 'handles nil cells by converting to empty string' do
      result = chat.wrap_table_rows([[ nil, 'text' ]], 2)
      expect(result[0][0]).to eq('')
    end

    it 'preserves short content without wrapping' do
      rows   = [[ 'hi', 'there' ]]
      result = chat.wrap_table_rows(rows, 2)
      expect(result[0]).to eq(['hi', 'there'])
    end
  end

  describe '#table_column_budgets' do
    it 'returns equal budgets when total width is zero' do
      result = chat.table_column_budgets([[ '', '' ]], 2)
      expect(result[0]).to eq(result[1])
    end

    it 'allocates proportionally based on content width' do
      narrow = 'a'
      wide   = 'a' * 20
      result = chat.table_column_budgets([[ narrow, wide ]], 2)
      expect(result[1]).to be > result[0]
    end
  end
end
