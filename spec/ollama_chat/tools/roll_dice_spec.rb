describe OllamaChat::Tools::RollDice do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  connect_to_ollama_server

  let :tool do
    described_class.new
  end

  it 'can have name' do
    expect(tool.name).to eq 'roll_dice'
  end

  it 'can have tool' do
    expect(tool.tool).to be_a Ollama::Tool
  end

  let :arguments do
    OpenStruct.new(
      dice: nil,
    )
  end

  it 'can be executed successfully with 2d6 notation' do
    arguments.dice = '2d6'
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'roll_dice',
        arguments:
      )
    )

    expect(tool).to receive(:rand).with(1..6).and_return(2, 5)

    result = tool.execute(tool_call, chat:)

    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.dice).to eq '2d6'
    expect(json.rolls).to eq [2, 5]
    expect(json.modifier).to eq 0
    expect(json.total).to eq 7
  end

  it 'can be executed successfully with d20 notation' do
    arguments.dice = 'd20'
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'roll_dice',
        arguments:
      )
    )

    expect(tool).to receive(:rand).with(1..20).and_return(10)

    result = tool.execute(tool_call, chat:)

    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.rolls).to eq [10]
    expect(json.total).to eq 10
  end

  it 'can be executed successfully with positive modifier' do
    arguments.dice = 'd20+3'
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'roll_dice',
        arguments:
      )
    )

    expect(tool).to receive(:rand).with(1..20).and_return(15)

    result = tool.execute(tool_call, chat:)

    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.rolls).to eq [15]
    expect(json.modifier).to eq 3
    expect(json.total).to eq 18
  end

  it 'can be executed successfully with negative modifier' do
    arguments.dice = 'd20-3'
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'roll_dice',
        arguments:
      )
    )

    expect(tool).to receive(:rand).with(1..20).and_return(5)

    result = tool.execute(tool_call, chat:)

    expect(result).to be_a(String)
    json = json_object(result)
    expect(json.rolls).to eq [5]
    expect(json.modifier).to eq(-3)
    expect(json.total).to eq 2
  end

  it 'can handle invalid dice notation' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'roll_dice',
        arguments:
      )
    )

    result = tool.execute(tool_call, chat:)

    expect(result).to be_a(String)
    json = json_object(result)
    expect(json['error']).to eq 'OllamaChat::ToolFunctionArgumentError'
  end

  it 'can be converted to hash' do
    expect(tool.to_hash).to be_a Hash
  end
end
