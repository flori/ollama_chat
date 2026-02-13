require 'spec_helper'

describe OllamaChat::Tools::OpenFileInEditor do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  let :config do
    chat.config
  end

  connect_to_ollama_server

  it 'can have name' do
    expect(described_class.new.name).to eq 'open_file_in_editor'
  end

  it 'can have tool' do
    expect(described_class.new.tool).to be_a Ollama::Tool
  end

  it 'can be executed successfully with valid path and start_line' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'open_file',
        arguments: double(
          path: asset('example.rb'),
          start_line: 42,
          end_line: nil
        )
      )
    )
    expect(chat).to receive(:vim).and_return(double('Vim', open_file: true))

    result = described_class.new.execute(tool_call, chat:)
    json = json_object(result)
    expect(json.path).to eq asset('example.rb')
    expect(json.start_line).to eq 42
  end

  it 'can be executed successfully with valid path, start_line, end_line' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'open_file',
        arguments: double(
          path: asset('example.rb'),
          start_line: 23,
          end_line: 42
        )
      )
    )
    expect(chat).to receive(:vim).and_return(double('Vim', open_file: true))

    result = described_class.new.execute(tool_call, chat:)
    json = json_object(result)
    expect(json.path).to eq asset('example.rb')
    expect(json.start_line).to eq 23
    expect(json.end_line).to eq 42
  end

  it 'can handle invalid path gracefully' do
    tool_call = double(
      'ToolCall',
      function: double(
        name: 'open_file',
        arguments: double(
          path: '/non/existent',
          start_line: 1,
          end_line: nil
        )
      )
    )

    result = described_class.new.execute(tool_call, chat:)
    json = json_object(result)

    expect(json.error).to eq 'Errno::ENOENT'
    expect(json.message).to include('No such file or directory')
  end

  it 'can be converted to hash' do
    expect(described_class.new.to_hash).to be_a Hash
  end
end
