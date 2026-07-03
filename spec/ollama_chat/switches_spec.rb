describe OllamaChat::Switches do
  describe OllamaChat::Switches::Switch do
    let :switch do
      described_class.new(
        value: config.test,
        msg: {
          true  => "Enabled.",
          false => "Disabled.",
        }
      )
    end

    context 'callbacks' do
      let(:callback_on) { double('callback_on') }
      let(:callback_off) { double('callback_off') }
      let :switch do
        described_class.new(
          value: false,
          msg: { true => "On", false => "Off" },
          callbacks: {
            [false, true]  => callback_on,
            [true, false]  => callback_off
          }
        )
      end

      it 'triggers the on-callback when switching from false to true' do
        expect(callback_on).to receive(:call).with(false, true)
        expect(callback_off).not_to receive(:call)
        switch.set(true)
      end

      it 'triggers the off-callback when switching from true to false' do
        expect(callback_on).to receive(:call).with(false, true)
        switch.set(true) # Setup state to true
        expect(callback_off).to receive(:call).with(true, false)
        expect(callback_on).not_to receive(:call)
        switch.set(false)
      end

      it 'does not trigger any callback when value remains the same' do
        expect(callback_on).not_to receive(:call)
        expect(callback_off).not_to receive(:call)
        switch.set(false)
      end

      it 'triggers callbacks via toggle' do
        expect(callback_on).to receive(:call).with(false, true)
        switch.toggle
      end
    end

    context 'default to false' do
      let :config do
        double(test: false)
      end

      it 'can be switched on' do
        expect {
          switch.set(true)
        }.to change {
          switch.on? && !switch.off?
        }.from(false).to(true)
      end

      it 'can be toggled on' do
        expect(STDOUT).to receive(:puts).with('Enabled.')
        expect {
          switch.toggle
        }.to change {
          switch.on? && !switch.off?
        }.from(false).to(true)
      end
    end

    context 'default to true' do
      let :config do
        double(test: true)
      end

      it 'can be switched on' do
        expect {
          switch.set(false)
        }.to change {
          switch.on? && !switch.off?
        }.from(true).to(false)
      end

      it 'can be toggled off' do
        expect(STDOUT).to receive(:puts).with('Disabled.')
        expect {
          switch.toggle
        }.to change {
          switch.on? && !switch.off?
        }.from(true).to(false)
      end
    end
  end

  describe OllamaChat::Switches::DatabaseSwitch do
    let :session do
      double('Session')
    end

    let :chat do
      double('Chat', session:)
    end

    let :switch do
      described_class.new(
        chat:,
        attribute: :test,
        msg: {
          true  => "Enabled.",
          false => "Disabled.",
        }
      )
    end

    context 'callbacks' do
      let(:callback_on) { double('callback_on') }
      let(:callback_off) { double('callback_off') }
      let :switch do
        described_class.new(
          chat:,
          attribute: :test,
          msg: { true => "On", false => "Off" },
          callbacks: {
            [false, true]  => callback_on,
            [true, false]  => callback_off
          }
        )
      end

      it 'triggers the on-callback when switching from false to true' do
        expect(session).to receive(:send).with(:test).and_return false, true, true
        expect(session).to receive(:update).with("test": true)
        expect(callback_on).to receive(:call).with(false, true)
        switch.set(true)
      end

      it 'triggers the off-callback when switching from true to false' do
        expect(session).to receive(:send).with(:test).and_return true, false, false
        expect(session).to receive(:update).with("test": false)
        expect(callback_off).to receive(:call).with(true, false)
        switch.set(false)
      end

      it 'does not trigger callbacks when value remains the same' do
        expect(session).to receive(:send).with(:test).and_return false, false
        expect(session).to receive(:update).with("test": false)
        expect(callback_on).not_to receive(:call)
        switch.set(false)
      end
    end

    context 'default to false' do
      it 'can be switched on' do
        expect(session).to receive(:send).with(:test).and_return false, false, true, true
        expect(session).to receive(:update).with("test": true)
        expect {
          switch.set(true)
        }.to change {
          switch.on?
        }.from(false).to(true)
      end

      it 'can be toggled on' do
        expect(session).to receive(:send).with(:test).and_return false, false, false, true, true, true
        expect(session).to receive(:update).with("test": true)
        expect(STDOUT).to receive(:puts).with('Enabled.')
        expect {
          switch.toggle
        }.to change {
          switch.on?
        }.from(false).to(true)
      end
    end

    context 'default to true' do
      it 'can be switched on' do
        expect(session).to receive(:send).with(:test).and_return true, true, false, false
        expect(session).to receive(:update).with("test": false)
        expect {
          switch.set(false)
        }.to change {
          switch.on?
        }.from(true).to(false)
      end

      it 'can be toggled off' do
        expect(session).to receive(:send).with(:test).and_return true, true, true, false, false, false
        expect(session).to receive(:update).with("test": false)
        expect(STDOUT).to receive(:puts).with('Disabled.')
        expect {
          switch.toggle
        }.to change {
          switch.on?
        }.from(true).to(false)
      end
    end
  end

  describe OllamaChat::Switches::CombinedSwitch do
    describe 'off' do
      let :config do
        double(test1: true, test2: false)
      end

      let :switch1 do
        OllamaChat::Switches::Switch.new(
          value: config.test1,
          msg: {
            true  => "Enabled.",
            false => "Disabled.",
          }
        )
      end

      let :switch2 do
        OllamaChat::Switches::Switch.new(
          value: config.test2,
          msg: {
            true  => "Enabled.",
            false => "Disabled.",
          }
        )
      end

      let :switch do
        described_class.new(
          value: -> { switch1.on? && switch2.off? },
          msg: {
            true  => "Enabled.",
            false => "Disabled.",
          }
        )
      end

      it 'can be switched off 2' do
        expect {
          switch2.set(true)
        }.to change {
          switch.on? && !switch.off?
        }.from(true).to(false)
      end

      it 'can be switched off 1' do
        expect {
          switch1.set(false)
        }.to change {
          switch.on? && !switch.off?
        }.from(true).to(false)
      end
    end

    describe 'on' do
      let :config do
        double(test1: false, test2: true)
      end

      let :switch1 do
        OllamaChat::Switches::Switch.new(
          value: config.test1,
          msg: {
            true  => "Enabled.",
            false => "Disabled.",
          }
        )
      end

      let :switch2 do
        OllamaChat::Switches::Switch.new(
          value: config.test2,
          msg: {
            true  => "Enabled.",
            false => "Disabled.",
          }
        )
      end

      let :switch do
        described_class.new(
          value: -> { switch1.on? && switch2.off? },
          msg: {
            true  => "Enabled.",
            false => "Disabled.",
          }
        )
      end

      it 'can be switched on' do
        switch
        expect {
          switch1.set(true)
          switch2.set(false)
        }.to change {
          switch.on? && !switch.off?
        }.from(false).to(true)
      end
    end
  end
end
