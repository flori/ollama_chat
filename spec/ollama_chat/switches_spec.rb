require 'spec_helper'

describe OllamaChat::Switches do
  describe OllamaChat::Switches::Switch do
    let :switch do
      described_class.new(
        :test,
        config: config,
        msg: {
          true  => "Enabled.",
          false => "Disabled.",
        }
      )
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

    context 'default to false' do
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

  describe OllamaChat::Switches::CombinedSwitch do
    describe 'off' do
      let :config do
        double(test1: true, test2: false)
      end

      let :switch1 do
        OllamaChat::Switches::Switch.new(
          :test1,
          config: config,
          msg: {
            true  => "Enabled.",
            false => "Disabled.",
          }
        )
      end

      let :switch2 do
        OllamaChat::Switches::Switch.new(
          :test2,
          config: config,
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
          :test1,
          config: config,
          msg: {
            true  => "Enabled.",
            false => "Disabled.",
          }
        )
      end

      let :switch2 do
        OllamaChat::Switches::Switch.new(
          :test2,
          config: config,
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
