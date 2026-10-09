describe OllamaChat::ContextUsage do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config).expose
  end

  connect_to_ollama_server

  before do
    const_conf_as('OC::PAGER' => nil)
  end

  # Stubs the chat surface the context usage reads so the thresholds are
  # deterministic and no live server / message list is required.
  #
  # Uses `allow` (not `expect`) because not every context usage method touches
  # every accessor: `plain`/`filled`/`percent` never read the compaction
  # budgets, and `percent` re-enters `filled` (so `messages` is hit twice).
  # The behavioral assertions below carry the verification weight.
  def stub_context(tokens:, length:, keep_recent:, reserve:)
    est = OllamaChat::TokenEstimator::Estimate.new(bytes: 0, tokens:)
    allow(chat).to receive(:messages).and_return(
      double(compacted_estimate_tokens: est)
    )
    allow(chat).to receive(:current_context_length).and_return length
    allow(chat).to receive(:compact_ratio_tokens).with(:keep_recent, length).and_return keep_recent
    allow(chat).to receive(:compact_ratio_tokens).with(:reserve, length).and_return reserve
  end

  it 'paints green below the keep_recent budget' do
    stub_context(tokens: 100, length: 1000, keep_recent: 500, reserve: 800)
    expect(described_class.new(chat).colored).to include('🟢')
  end

  it 'paints yellow between keep_recent and reserve' do
    stub_context(tokens: 600, length: 1000, keep_recent: 500, reserve: 800)
    expect(described_class.new(chat).colored).to include('🟡')
  end

  it 'paints red above the reserve budget' do
    stub_context(tokens: 900, length: 1000, keep_recent: 500, reserve: 800)
    expect(described_class.new(chat).colored).to include('🔴')
  end

  it 'returns an uncolored usage string for plain' do
    stub_context(tokens: 100, length: 1000, keep_recent: 500, reserve: 800)
    expect(described_class.new(chat).plain).to eq '10.0% · 100.0 T of 1.0 KT'
  end

  it 'returns nil for plain when the context length is unknown' do
    expect(chat).to receive(:current_context_length).and_return nil
    expect(described_class.new(chat).plain).to be_nil
  end

  it 'falls back to a bold n/a for colored when unknown' do
    expect(chat).to receive(:current_context_length).and_return nil
    expect(described_class.new(chat).colored).to include('n/a')
  end

  it 'exposes the fill ratio and percentage' do
    stub_context(tokens: 500, length: 1000, keep_recent: 500, reserve: 800)
    p = described_class.new(chat)
    expect(p.filled).to eq 0.5
    expect(p.percent).to eq '50.0%'
  end
end
