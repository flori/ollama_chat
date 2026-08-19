describe OllamaChat::WebSearching do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config).expose
  end

  connect_to_ollama_server

  before do
    const_conf_as('OC::PAGER' => nil)
  end

  describe '#search_web' do
    it 'returns nil and warns for an unimplemented engine' do
      expect(chat).to receive(:search_engine).and_return('nonexistent')
      expect(STDOUT).to receive(:puts).with(/not implemented/)
      expect(chat.search_web('ruby')).to be_nil
    end

    it 'delegates to the engine method and collects links' do
      expect(chat).to receive(:search_engine).and_return('duckduckgo')
      urls = %w[https://a.example https://b.example]
      expect(chat).to receive(:search_web_with_duckduckgo)
        .with(/ruby/, 2).and_return(urls)
      expect(chat).to receive(:log).at_least(:once)
      expect(chat.links).to receive(:add).twice
      expect(chat.search_web('ruby', 2)).to eq(urls)
    end

    it 'clamps n below 1 to a minimum of 1' do
      expect(chat).to receive(:search_engine).and_return('duckduckgo')
      expect(chat).to receive(:search_web_with_duckduckgo)
        .with(/ruby/, 1).and_return(%w[https://a.example])
      expect(chat).to receive(:log).at_least(:once)
      chat.search_web('ruby', 0)
    end
  end

  describe '#web' do
    let(:urls) { %w[https://a.example https://b.example] }

    it 'returns :next when no search results are found' do
      expect(chat).to receive(:search_web).and_return(nil)
      expect(chat.web('1', 'ruby')).to be(:next)
    end

    context 'when policy is embedding and embedding is on' do
      before do
         expect(chat.document_policy).to receive(:selected).
           at_least(:once).and_return('embedding')
        expect(chat.instance_variable_get(:@embedding)).
          to receive(:on?).and_return(true)
      end

      it 'embeds each source and interpolates the web_embed prompt' do
        expect(chat).to receive(:prompt).with(:web_embed).
          and_return(double('prompt', to_s: 'Search for: %{query}'))
        expect(chat).to receive(:search_web).and_return(urls)
         expect(chat).to receive(:fetch_source).twice do |_url, &block|
           block&.call(nil)
         end
        expect(chat).to receive(:embed_source).twice
        result = chat.web('2', 'ruby tutorials')
        expect(result).to eq('Search for: ruby tutorials')
      end
    end

    context 'when policy is summarizing' do
      before do
         expect(chat.document_policy).to receive(:selected).
           at_least(:once).and_return('summarizing')
      end

      it 'summarizes each URL and interpolates the prompt' do
        expect(chat).to receive(:prompt).with(:web_import).
          and_return(double('prompt', to_s: 'Q: %{query} R: %{results}'))
        expect(chat).to receive(:search_web).and_return(urls)
        expect(chat).to receive(:summarize).twice
          .and_return('summary text')
        result = chat.web('2', 'ruby')
        expect(result).to eq('Q: ruby R: summary textsummary text')
      end
    end

    context 'when policy is importing (default)' do
      before do
         expect(chat.document_policy).to receive(:selected).
           at_least(:once).and_return('importing')
      end

      it 'imports each URL and interpolates the prompt' do
        expect(chat).to receive(:prompt).with(:web_summarize).
          and_return(double('prompt', to_s: 'Q: %{query} R: %{results}'))
        expect(chat).to receive(:search_web).and_return(urls)
        expect(chat).to receive(:import).twice
          .and_return('imported text')
        result = chat.web('2', 'ruby')
        expect(result).to eq('Q: ruby R: imported textimported text')
      end
    end
  end

  describe '#manage_links' do
    it 'prints a message when the link list is empty' do
      chat.links.clear
      expect(STDOUT).to receive(:puts).with('List is empty.')
      chat.manage_links(nil)
    end
  end
end
