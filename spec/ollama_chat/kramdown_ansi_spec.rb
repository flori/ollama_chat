require 'spec_helper'

describe OllamaChat::KramdownANSI do
  let :chat do
    double('Chat').extend(described_class)
  end

  describe '#configure_kramdown_ansi_styles', protect_env: true do
    it 'can be configured via env var' do
      const_conf_as(
        'OllamaChat::EnvConfig::KRAMDOWN_ANSI_OLLAMA_CHAT_STYLES' => '{"foo":"bar"}'
      )
      styles = { bold: '1' }
      expect(Kramdown::ANSI::Styles).to receive(:from_json).
        with('{"foo":"bar"}').
        and_return(double(ansi_styles: styles))

      expect(chat.configure_kramdown_ansi_styles).to eq(styles)
    end

    it 'has a default configuration' do
      const_conf_as(
        'OllamaChat::EnvConfig::KRAMDOWN_ANSI_OLLAMA_CHAT_STYLES' => nil
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
end
