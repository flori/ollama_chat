describe OllamaChat::Tools::ComputeBMI do
  let :chat do
    OllamaChat::Chat.new argv: chat_default_config
  end

  connect_to_ollama_server

  it 'can have name' do
    expect(described_class.new.name).to eq 'compute_bmi'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end

  describe '#execute' do
    context 'with SI units' do
      it 'calculates BMI correctly for Normal weight' do
        tool_call = double(
          'ToolCall',
          function: double(
            name: 'compute_bmi',
            arguments: double(weight: 70, height: 1.75, units: 'SI')
          )
        )

        result = described_class.new.execute(tool_call, chat: chat)
        json = json_object(result)

        expect(json.bmi).to be_within(0.01).of(22.86)
        expect(json.category).to eq 'Normal weight'
        expect(json.message).to match(
          /This BMI is 22\.8\d+, which falls into the Normal weight category\./
        )
      end

      it 'calculates BMI correctly for Underweight' do
        tool_call = double(
          'ToolCall',
          function: double(
            name: 'compute_bmi',
            arguments: double(weight: 45, height: 1.60, units: 'SI')
          )
        )

        result = described_class.new.execute(tool_call, chat: chat)
        json = json_object(result)

        expect(json.bmi).to be_within(0.01).of(17.58)
        expect(json.category).to eq 'Underweight'
        expect(json.message).to match(
          /This BMI is 17\.5\d+, which falls into the Underweight category\./
        )
      end
    end

    context 'with USCS units' do
      it 'converts pounds and inches to metric and calculates correctly' do
        tool_call = double(
          'ToolCall',
          function: double(
            name: 'compute_bmi',
            arguments: double(weight: 150, height: 70, units: 'USCS')
          )
        )

        result = described_class.new.execute(tool_call, chat: chat)
        json = json_object(result)

        expect(json.bmi).to be_within(0.01).of(21.52)
        expect(json.category).to eq 'Normal weight'
        expect(json.message).to match(
          /This BMI is 21\.5\d+, which falls into the Normal weight category\./
        )
      end
    end

    context 'error handling' do
      it 'returns error when weight is missing' do
        tool_call = double(
          'ToolCall',
          function: double(
            name: 'compute_bmi',
            arguments: double(weight: nil, height: 1.75, units: nil)
          )
        )

        result = described_class.new.execute(tool_call, chat: chat)
        json = json_object(result)

        expect(json.error).to eq 'OllamaChat::ToolFunctionArgumentError'
        expect(json.message).to include 'no weight given'
      end

      it 'returns error when height is zero' do
        tool_call = double(
          'ToolCall',
          function: double(
            name: 'compute_bmi',
            arguments: double(weight: 70, height: 0, units: nil)
          )
        )

        result = described_class.new.execute(tool_call, chat: chat)
        json = json_object(result)

        expect(json.error).to eq 'OllamaChat::ToolFunctionArgumentError'
        expect(json.message).to include 'Height must be greater than zero'
      end
    end
  end
end
