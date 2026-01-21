require 'spec_helper'

describe OllamaChat::ThinkControl do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  connect_to_ollama_server

  describe '#think' do
    it 'returns false when the think mode selector is off' do
      chat.think_mode.selected = 'disabled'
      expect(chat.think).to be false
    end

    it 'returns true when the think mode selector is enabled' do
      chat.think_mode.selected = 'enabled'
      expect(chat.think).to be true
    end

    it 'returns the selected value when it is not “enabled”' do
      chat.think_mode.selected = 'low'
      expect(chat.think).to eq 'low'
    end
  end

  describe '#think?' do
    it 'returns true when the think mode selector is on' do
      chat.think_mode.selected = 'enabled'
      expect(chat.think?).to be true
    end

    it 'returns true when the think mode selector is on but the value is a string' do
      chat.think_mode.selected = 'high'
      expect(chat.think?).to be true
    end

    it 'returns false when the think mode selector is off' do
      chat.think_mode.selected = 'disabled'
      expect(chat.think?).to be false
    end
  end

  describe '#think_mode' do
    it 'exposes a StateSelector instance' do
      expect(chat.think_mode).to be_a OllamaChat::StateSelectors::StateSelector
    end

    it 'has the correct default selection (disabled)' do
      expect(chat.think_mode.selected).to eq 'disabled'
    end
  end

  describe '#think_loud?' do
    it 'returns false when the think mode selector is off' do
      chat.think_mode.selected = 'disabled'
      expect(chat.think_loud?).to be false
    end

    it 'returns false when the think_loud switch is off' do
      chat.think_mode.selected = 'enabled'
      allow(chat).to receive(:think_loud).and_return(double(on?: false))
      expect(chat.think_loud?).to be false
    end

    it 'returns true when both the think mode selector and think_loud switch are on' do
      chat.think_mode.selected = 'enabled'
      allow(chat).to receive(:think_loud).and_return(double(on?: true))
      expect(chat.think_loud?).to be true
    end
  end

  describe '#think_mode.show' do
    it 'prints the current think mode in bold' do
      chat.think_mode.selected = 'high'
      expect(STDOUT).to receive(:puts).with(/Think mode is \e\[1mhigh\e\[0m/)
      chat.think_mode.show
    end

    it 'prints “disabled” when the selector is off' do
      chat.think_mode.selected = 'disabled'
      expect(STDOUT).to receive(:puts).with(/Think mode is \e\[1mdisabled\e\[0m/)
      chat.think_mode.show
    end
  end

  describe '#think_mode.choose' do
    it 'updates the selector based on the user choice' do
      expect(OllamaChat::Utils::Chooser).to receive(:choose).and_return('low')
      chat.think_mode.choose
      expect(chat.think_mode.selected).to eq 'low'
    end
  end
end
