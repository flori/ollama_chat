require 'spec_helper'

describe OllamaChat::StateSelectors::StateSelector do
  let(:name) { 'Test Selector' }
  let(:states) { %w[ enabled disabled low high ] }
  let(:default) { 'enabled' }
  let(:off) { %w[ disabled ] }

  let(:selector) do
    described_class.new(
      name: name,
      states: states,
      default: default,
      off: off
    )
  end

  describe '#initialize' do
    it 'creates a new StateSelector with provided parameters' do
      expect(selector).to be_a described_class
    end

    it 'sets the name correctly' do
      expect(selector.instance_variable_get(:@name)).to eq name
    end

    it 'sets the states correctly' do
      expect(selector.instance_variable_get(:@states)).to eq Set.new(states)
    end

    it 'sets the default state' do
      expect(selector.instance_variable_get(:@default)).to eq default
    end

    it 'sets the off states correctly' do
      expect(selector.instance_variable_get(:@off)).to eq off
    end

    it 'sets the selected state to default' do
      expect(selector.selected).to eq default
    end

    context 'with empty states' do
      it 'raises ArgumentError when states are empty' do
        expect {
          described_class.new(name: 'Test', states: [])
        }.to raise_error(ArgumentError, 'states cannot be empty')
      end
    end

    context 'with invalid default' do
      it 'raises ArgumentError when default is not in states' do
        expect {
          described_class.new(name: 'Test', states: %w[ a b ], default: 'c')
        }.to raise_error(ArgumentError, 'default has to be one of a, b.')
      end
    end
  end

  describe '#selected' do
    it 'returns the currently selected state' do
      expect(selector.selected).to eq default
    end
  end

  describe '#selected=' do
    it 'sets the selected state to a valid value' do
      selector.selected = 'low'
      expect(selector.selected).to eq 'low'
    end

    it 'raises ArgumentError when setting invalid state' do
      expect {
        selector.selected = 'invalid'
      }.to raise_error(ArgumentError, 'value has to be one of enabled, disabled, low, high.')
    end
  end

  describe '#allow_empty?' do
    it 'returns false by default' do
      expect(selector.allow_empty?).to be false
    end

    context 'when allow_empty is true' do
      let(:selector) do
        described_class.new(
          name: name,
          states: states,
          default: nil,
          allow_empty: true
        )
      end

      it 'returns true when allow_empty is set' do
        expect(selector.allow_empty?).to be true
      end
    end
  end

  describe '#off?' do
    it 'returns true when selected state is in off set' do
      selector.selected = 'disabled'
      expect(selector.off?).to be true
    end

    it 'returns false when selected state is not in off set' do
      selector.selected = 'enabled'
      expect(selector.off?).to be false
    end
  end

  describe '#on?' do
    it 'returns true when selected state is not in off set' do
      selector.selected = 'enabled'
      expect(selector.on?).to be true
    end

    it 'returns false when selected state is in off set' do
      selector.selected = 'disabled'
      expect(selector.on?).to be false
    end
  end

  describe '#choose' do
    it 'allows user to select a state from available options' do
      # Mock the chooser to return a specific choice
      expect(OllamaChat::Utils::Chooser).to receive(:choose).with(
        %w[ enabled disabled low high [EXIT] ]
      ).and_return('low')

      selector.choose
      expect(selector.selected).to eq 'low'
    end

    it 'exits when user selects [EXIT]' do
      expect(OllamaChat::Utils::Chooser).to receive(:choose).and_return('[EXIT]')

      selector.choose
      expect(selector.selected).to eq default
    end

    it 'exits when user cancels selection' do
      expect(OllamaChat::Utils::Chooser).to receive(:choose).and_return(nil)

      selector.choose
      expect(selector.selected).to eq default
    end
  end

  describe '#show' do
    it 'outputs the current state to stdout' do
      expect(STDOUT).to receive(:puts).with(/Test Selector is .*?enabled.*?\./)
      selector.show
    end
  end

  describe '#to_s' do
    it 'returns the string representation of the selected state' do
      expect(selector.to_s).to eq default
    end

    it 'returns the string representation after changing state' do
      selector.selected = 'low'
      expect(selector.to_s).to eq 'low'
    end
  end

  describe 'with allow_empty true' do
    let(:selector) do
      described_class.new(
        name: 'Empty Selector',
        states: %w[ a b c ],
        default: nil,
        allow_empty: true
      )
    end

    it 'allows setting nil as selected state' do
      selector.selected = nil
      expect(selector.selected).to eq ""
    end

    it 'allows empty state when allow_empty is true' do
      expect(selector.allow_empty?).to be true
    end

    it 'raises no error when setting invalid state' do
      expect {
        selector.selected = 'invalid'
      }.not_to raise_error
    end
  end
end
