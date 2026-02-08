require 'spec_helper'

describe OllamaChat::MessageList do
  let :config do
    double(
      location: double(
        enabled: false,
        name: 'Berlin',
        decimal_degrees: [ 52.514127, 13.475211 ],
        units: 'SI (International System of Units)'
      ),
      prompts: double(
        location: 'You are at %{location_name} (%{location_decimal_degrees}),' \
        ' on %{localtime}, preferring %{units}'
      ),
      system_prompts: double(
        assistant?: 'You are a helpful assistant.'
      )
    )
  end

  let :chat do
    double('Chat', config:)
  end

  before do
    chat.extend OllamaChat::LocationHandling
  end

  before do
    allow(chat).to receive(:kramdown_ansi_parse) do |content|
      Kramdown::ANSI.parse(content)
    end
  end

  let :list do
    described_class.new(chat).tap do |list|
      list << Ollama::Message.new(role: 'system', content: 'hello')
    end
  end

  it 'can clear non system messages' do
    expect(list.size).to eq 1
    list.clear
    expect(list.size).to eq 1
    list << Ollama::Message.new(role: 'user', content: 'world')
    expect(list.size).to eq 2
    list.clear
    expect(list.size).to eq 1
  end

  it 'can be added to' do
    expect(list.size).to eq 1
    list << Ollama::Message.new(role: 'user', content: 'world')
    expect(list.size).to eq 2
  end

  it 'has a last message' do
    expect(list.last).to be_a Ollama::Message
  end

  it 'can load conversations if existing' do
    expect(list.messages.first.role).to eq  'system'
    expect(list.load_conversation(asset('conversation-nixda.json'))).to be_nil
    expect {
      list.load_conversation(asset('conversation.json'))
    }.to change { list.messages.size }.from(1).to(3)
    expect(list.messages.map(&:role)).to eq %w[ system user assistant ]
  end

  it 'can save conversations' do
    expect(list.save_conversation('tmp/test-conversation.json')).to eq list
  ensure
    FileUtils.rm_f 'tmp/test-conversation.json'
  end

  describe "#last" do
    it "returns the last message when there are multiple messages" do
      list = described_class.new(chat)
      list << Ollama::Message.new(role: 'system', content: 'hello')
      list << Ollama::Message.new(role: 'user', content: 'First message')
      list << Ollama::Message.new(role: 'assistant', content: 'Second message')

      expect(list.last.content).to eq('Second message')
    end

    it "returns the last message when there is only one message" do
      list = described_class.new(chat)
      list << Ollama::Message.new(role: 'system', content: 'hello')

      expect(list.last.content).to eq('hello')
    end

    it "returns nil when there are no messages" do
      list = described_class.new(chat)

      expect(list.last).to be_nil
    end
  end

  describe '#show_last' do
    it 'shows nothing when there are no messages' do
      empty_list = described_class.new(chat)
      expect { empty_list.show_last }.not_to raise_error
      expect(empty_list.show_last).to be nil
    end

    it 'shows nothing when the last message is by the assistant' do
      list = described_class.new(chat)
      allow(chat).to receive(:think?).and_return(false)
      allow(chat).to receive(:markdown).and_return(double(on?: false))
      list << Ollama::Message.new(role: 'assistant', content: 'hello')
      expect(STDOUT).to receive(:puts).
        with("📨 \e[1m\e[38;5;111massistant\e[0m\e[0m:\nhello\n")
      expect(list.show_last).to be_a described_class
    end

    it 'shows nothing when the last message is by the user' do
      list = described_class.new(chat)
      list << Ollama::Message.new(role: 'user', content: 'world')
      expect { list.show_last }.not_to raise_error
      expect(list.show_last).to be nil
    end

    it "shows last N messages when N is larger than available messages" do
      allow(chat).to receive(:think?).and_return(false)
      allow(chat).to receive(:markdown).and_return(double(on?: false))
      list = described_class.new(chat)
      list << Ollama::Message.new(role: 'system', content: 'hello')
      list << Ollama::Message.new(role: 'user', content: 'First message')
      list << Ollama::Message.new(role: 'assistant', content: 'Second message')

      expect(STDOUT).to receive(:puts).with(/Second message/)
      expect(list.show_last(23)).to eq(list)
    end
  end

  context 'without pager' do
    before do
      expect(list).to receive(:determine_pager_command).and_return nil
    end

    it 'can show last message' do
      expect(chat).to receive(:markdown).
        and_return(double(on?: true)).at_least(:once)
      expect(chat).to receive(:think?).and_return(false).at_least(:once)
      expect(STDOUT).to receive(:puts).
        with("📨 \e[1m\e[38;5;213msystem\e[0m\e[0m:\nhello\n")
      list.show_last
    end

    it 'can list conversations without thinking' do
      expect(chat).to receive(:markdown).
        and_return(double(on?: true)).at_least(:once)
      expect(chat).to receive(:think?).and_return(false).at_least(:once)
      list << Ollama::Message.new(role: 'user', content: 'world')
      expect(STDOUT).to receive(:puts).
        with(
          "📨 \e[1m\e[38;5;213msystem\e[0m\e[0m:\nhello\n" \
          "📨 \e[1m\e[38;5;172muser\e[0m\e[0m:\nworld\n"
        )
      list.list_conversation
    end

    it 'can list conversations with thinking' do
      expect(chat).to receive(:markdown).
        and_return(double(on?: true)).at_least(:once)
      expect(chat).to receive(:think?).and_return(true).at_least(:once)
      expect(STDOUT).to receive(:puts).
        with(
          "📨 \e[1m\e[38;5;213msystem\e[0m\e[0m:\n" \
          "💭\nI need to say something nice…\n\n💬\nhello\n" \
          "📨 \e[1m\e[38;5;172muser\e[0m\e[0m:\nworld\n"
        )
      list.set_system_prompt nil
      list << Ollama::Message.new(
        role: 'system', content: 'hello',
        thinking: 'I need to say something nice…'
      )
      list << Ollama::Message.new(role: 'user', content: 'world')
      list.list_conversation
    end
  end

  context 'with pager' do
    before do
      expect(list).to receive(:determine_pager_command).and_return 'true'
      expect(Tins::Terminal).to receive(:lines).and_return 1
    end

    it 'can list conversations' do
      skip 'no tty' unless STDOUT.tty?
      expect(chat).to receive(:markdown).
        and_return(double(on?: true)).at_least(:once)
      expect(chat).to receive(:think?).and_return(false).at_least(:once)
      list << Ollama::Message.new(role: 'user', content: 'world')
      list.list_conversation
    end
  end

  it 'can show_system_prompt' do
    expect(list).to receive(:system).and_return 'test **prompt**'
    expect(list.show_system_prompt).to eq list
  end

  it 'can set_system_prompt if unset' do
    list.messages.clear
    expect(list.messages.count { _1.role == 'system' }).to eq 0
    expect {
      expect(list.set_system_prompt('test prompt')).to eq list
    }.to change { list.system }.from(nil).to('test prompt')
    expect(list.messages.count { _1.role == 'system' }).to eq 1
  end

  it 'can set_system_prompt if already set' do
    list.messages.clear
    expect(list.messages.count { _1.role == 'system' }).to eq 0
    list.set_system_prompt('first prompt')
    expect(list.system).to eq('first prompt')
    expect(list.messages.count { _1.role == 'system' }).to eq 1
    #
    list.set_system_prompt('new prompt')
    expect(list.system).to eq('new prompt')
    expect(list.messages.count { _1.role == 'system' }).to eq 1
    expect(list.messages.first.role).to eq('system')
    expect(list.messages.first.content).to eq('new prompt')
  end

  it 'can drop n conversations exhanges' do
    expect(list.size).to eq 1
    expect(list.drop(1)).to eq 0
    expect(list.size).to eq 1
    list << Ollama::Message.new(role: 'user', content: 'world')
    expect(list.size).to eq 2
    list << Ollama::Message.new(role: 'assistant', content: 'hi')
    expect(list.size).to eq 3
    expect(list.drop(1)).to eq 1
    expect(list.size).to eq 1
    expect(list.drop(1)).to eq 0
    expect(list.size).to eq 1
    expect(list.drop(1)).to eq 0
    expect(list.size).to eq 1
  end

  it 'drops the last user message when there is no assistant response' do
    expect(list.size).to eq 1
    list << Ollama::Message.new(role: 'user', content: 'hello')
    list << Ollama::Message.new(role: 'assistant', content: 'hi')
    list << Ollama::Message.new(role: 'user', content: 'world')
    expect(list.size).to eq 4
    expect(list.drop(1)).to eq 1
    expect(list.size).to eq 3
    expect(list.drop(1)).to eq 1
    expect(list.size).to eq 1
  end

  it 'can determine location for system prompt' do
    expect(chat).to receive(:location).and_return(double(on?: true))
    expect(list.send(:at_location)).to match(
      %r(You are at Berlin \(52.514127, 13.475211\), on))
  end

  it 'can be converted int an Ollama::Message array' do
    expect(chat).to receive(:location).and_return(double(on?: false))
    list << Ollama::Message.new(role: 'user', content: 'world')
    expect(list.to_ary.map(&:as_json)).to eq [
      Ollama::Message.new(role: 'system', content: 'hello').as_json,
      Ollama::Message.new(role: 'user', content: 'world').as_json,
    ]
  end

  it 'can be converted int an Ollama::Message array with location' do
    expect(chat).to receive(:location).and_return(double(on?: true))
    list << Ollama::Message.new(role: 'user', content: 'world')
    first = list.to_ary.first
    expect(first.role).to eq 'system'
    expect(first.content).to match(
      %r(You are at Berlin \(52.514127, 13.475211\), on))
  end

  it 'can be converted int an Ollama::Message array with location without a system prompt' do
    expect(chat).to receive(:location).and_return(double(on?: true))
    list = described_class.new(chat).tap do |list|
      list << Ollama::Message.new(role: 'user', content: 'hello')
      list << Ollama::Message.new(role: 'assistant', content: 'world')
    end
    first = list.to_ary.first
    expect(first.role).to eq 'system'
    expect(first.content).to match(
      %r(You are a helpful assistant.\n\nYou are at Berlin \(52.514127, 13.475211\), on))
  end


  it 'can display messages with images' do
    expect(list.message_type([])).to eq ?📨
  end

  it 'can display messages without images' do
    expect(list.message_type(%w[ image ])).to eq ?📸
  end
end
