require 'spec_helper'

describe OllamaChat::ThinkControl do
  let :chat do
    OllamaChat::Chat.new(
      argv: %w[ -f lib/ollama_chat/ollama_chat_config/default_config.yml ]
    )
  end

  connect_to_ollama_server

  describe '#think' do
    it 'returns the current think mode state' do
      expect(chat.think).to be false
      chat.instance_variable_set(:@think, true)
      expect(chat.think).to be true
      chat.instance_variable_set(:@think, false)
      expect(chat.think).to be false
      chat.instance_variable_set(:@think, 'low')
      expect(chat.think).to eq 'low'
    end
  end

  describe '#think?' do
    it 'returns true when think mode is enabled (boolean true)' do
      chat.instance_variable_set(:@think, true)
      expect(chat.think?).to be true
    end

    it 'returns true when think mode is enabled (string value)' do
      chat.instance_variable_set(:@think, 'high')
      expect(chat.think?).to be true
    end

    it 'returns false when think mode is disabled (boolean false)' do
      chat.instance_variable_set(:@think, false)
      expect(chat.think?).to be false
    end

    it 'returns false when think mode is nil' do
      chat.instance_variable_set(:@think, nil)
      expect(chat.think?).to be false
    end
  end

  describe '#think_mode' do
    it 'returns "enabled" when think is true' do
      chat.instance_variable_set(:@think, true)
      expect(chat.think_mode).to eq 'enabled'
    end

    it 'returns the think value when it is a string' do
      chat.instance_variable_set(:@think, 'medium')
      expect(chat.think_mode).to eq 'medium'
    end

    it 'returns "disabled" when think is false' do
      chat.instance_variable_set(:@think, false)
      expect(chat.think_mode).to eq 'disabled'
    end

    it 'returns "disabled" when think is nil' do
      chat.instance_variable_set(:@think, nil)
      expect(chat.think_mode).to eq 'disabled'
    end
  end

  describe '#think_show' do
    it 'displays the current think mode status' do
      chat.instance_variable_set(:@think, true)
      expect(STDOUT).to receive(:puts).with(/Think mode is \e\[1menabled\e\[0m\./)
      chat.think_show
    end

    it 'displays the think mode level when set to string' do
      chat.instance_variable_set(:@think, 'high')
      expect(STDOUT).to receive(:puts).with(/Think mode is \e\[1mhigh\e\[0m\./)
      chat.think_show
    end

    it 'displays "disabled" when think is false' do
      chat.instance_variable_set(:@think, false)
      expect(STDOUT).to receive(:puts).with(/Think mode is \e\[1mdisabled\e\[0m\./)
      chat.think_show
    end

    it 'displays "disabled" when think is nil' do
      chat.instance_variable_set(:@think, nil)
      expect(STDOUT).to receive(:puts).with(/Think mode is \e\[1mdisabled\e\[0m\./)
      chat.think_show
    end
  end

  describe '#think_loud?' do
    it 'returns false when think is disabled' do
      chat.instance_variable_set(:@think, false)
      expect(chat.think_loud?).to be false
    end

    it 'returns false when think_loud is off' do
      chat.instance_variable_set(:@think, true)
      allow(chat).to receive(:think_loud).and_return(double(on?: false))
      expect(chat.think_loud?).to be false
    end

    it 'returns true when both think and think_loud are enabled' do
      chat.instance_variable_set(:@think, true)
      allow(chat).to receive(:think_loud).and_return(double(on?: true))
      expect(chat.think_loud?).to be true
    end
  end

  describe '#choose_think_mode' do
    it 'can select "off" mode' do
      expect(OllamaChat::Utils::Chooser).to receive(:choose).and_return('off')
      chat.choose_think_mode
      expect(chat.think).to be false
    end

    it 'can select "on" mode' do
      expect(OllamaChat::Utils::Chooser).to receive(:choose).and_return('on')
      chat.choose_think_mode
      expect(chat.think).to be true
    end

    it 'can select "low" mode' do
      expect(OllamaChat::Utils::Chooser).to receive(:choose).and_return('low')
      chat.choose_think_mode
      expect(chat.think).to eq 'low'
    end

    it 'can select "medium" mode' do
      expect(OllamaChat::Utils::Chooser).to receive(:choose).and_return('medium')
      chat.choose_think_mode
      expect(chat.think).to eq 'medium'
    end

    it 'can select "high" mode' do
      expect(OllamaChat::Utils::Chooser).to receive(:choose).and_return('high')
      chat.choose_think_mode
      expect(chat.think).to eq 'high'
    end

    it 'can exit selection' do
      expect(OllamaChat::Utils::Chooser).to receive(:choose).and_return('[EXIT]')
      expect { chat.choose_think_mode }.not_to change { chat.think }
    end

    it 'can handle nil selection' do
      expect(OllamaChat::Utils::Chooser).to receive(:choose).and_return(nil)
      expect { chat.choose_think_mode }.not_to change { chat.think }
    end
  end
end
