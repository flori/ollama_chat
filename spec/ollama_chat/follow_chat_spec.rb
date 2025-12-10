require 'spec_helper'

describe OllamaChat::FollowChat do
  let :messages do
    [
      Ollama::Message.new(role: 'user', content: 'hello', images: []),
    ]
  end

  let :chat do
    double('Chat', markdown: double(on?: false), think_loud?: true,
           think?: false, debug: false, stream: double(on?: true))
  end

  let :follow_chat do
    described_class.new(chat:, messages:, output:).expose
  end

  let :output do
    double('output', :sync= => true)
  end

  it 'has .call' do
    expect(follow_chat).to receive(:call).with(:foo)
    follow_chat.call(:foo)
  end

  it 'can follow without markdown' do
    message = Ollama::Message.new(role: 'assistant', content: 'world')
    response = double(message:, done: false)
    expect(output).to receive(:print).with(
      "\e[2J", "\e[1;1H", "📨 \e[1m\e[38;5;111massistant:\e[0m\e[0m", "\n",
      "world"
    )
    follow_chat.call(response)
    response = double(
      message:              nil,
      done:                 true,
      total_duration:       777.77,
      eval_duration:        666.66,
      eval_count:           23,
      prompt_eval_duration: 42.0,
      prompt_eval_count:    7,
      load_duration:        33.45,
    )
    expect(output).to receive(:puts).with("", /eval_duration/)
    follow_chat.call(response)
  end

  context '#truncate_for_terminal' do
    it 'can truncate text for 5 lines' do
      text = (?A..?Z).to_a.join(?\n)
      expect(follow_chat.truncate_for_terminal(text, max_lines: 5)).to eq(
        (?V..?Z).to_a.join(?\n)
      )
    end

    it 'can truncate text for -1 lines' do
      text = (?A..?Z).to_a.join(?\n)
      expect(follow_chat.truncate_for_terminal(text, max_lines: -1)).to eq(?Z)
    end

    it 'can truncate text for 0 lines' do
      text = (?A..?Z).to_a.join(?\n)
      expect(follow_chat.truncate_for_terminal(text, max_lines: 0)).to eq(?Z)
    end

    it 'can truncate text for 1 lines' do
      text = (?A..?Z).to_a.join(?\n)
      expect(follow_chat.truncate_for_terminal(text, max_lines: 1)).to eq(?Z)
    end

    it 'can truncate text for 42 lines' do
      text = (?A..?Z).to_a.join(?\n)
      expect(follow_chat.truncate_for_terminal(text, max_lines: 42)).to eq(text)
    end
  end
end
