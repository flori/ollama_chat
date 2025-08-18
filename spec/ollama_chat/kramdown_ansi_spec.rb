require 'spec_helper'

describe OllamaChat::KramdownANSI do
  let :chat do
    double('Chat').extend(described_class)
  end

  describe '#configure_kramdown_ansi_styles' do
    it 'can be configured via env var' do
      allow(ENV).to receive(:key?).with('KRAMDOWN_ANSI_OLLAMA_CHAT_STYLES').and_return(true)
      allow(ENV).to receive(:key?).with('KRAMDOWN_ANSI_STYLES').and_return(false)

      styles = { bold: '1' }
      expect(Kramdown::ANSI::Styles).to receive(:from_env_var).
        with('KRAMDOWN_ANSI_OLLAMA_CHAT_STYLES').
        and_return(double(ansi_styles: styles))

      expect(chat.configure_kramdown_ansi_styles).to eq(styles)
    end

    it 'has a default configuration' do
      allow(ENV).to receive(:key?).with('KRAMDOWN_ANSI_OLLAMA_CHAT_STYLES').and_return(false)
      allow(ENV).to receive(:key?).with('KRAMDOWN_ANSI_STYLES').and_return(false)

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
end
