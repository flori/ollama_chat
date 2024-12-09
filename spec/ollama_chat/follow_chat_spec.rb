require 'spec_helper'

RSpec.describe OllamaChat::FollowChat do
  let :messages do
    [
      Ollama::Message.new(role: 'user', content: 'hello', images: []),
    ]
  end

  let :follow_chat do
    described_class.new(messages:, output:)
  end

  let :output do
    double('output', :sync= => true)
  end

  before do
    allow(OllamaChat::Chat).to receive(:config).and_return(double(debug: false))
  end

  it 'has .call' do
    expect(follow_chat).to receive(:call).with(:foo)
    follow_chat.call(:foo)
  end

  it 'can follow without markdown' do
    message = Ollama::Message.new(role: 'assistant', content: 'world')
    response = double(message:, done: false)
    expect(output).to receive(:puts).with(/assistant/)
    expect(output).to receive(:print).with(/world/)
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
end
