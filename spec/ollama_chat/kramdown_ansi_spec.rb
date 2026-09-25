describe OllamaChat::KramdownANSI do
  let :chat do
    double('Chat').extend(described_class)
  end

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
      input = "Name | Age\n------|-----\nFoo | 42"
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
  end
end
