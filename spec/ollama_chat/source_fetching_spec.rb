require 'spec_helper'

describe OllamaChat::SourceFetching do
  let :chat do
    OllamaChat::Chat.new(
      argv: %w[ -f lib/ollama_chat/ollama_chat_config/default_config.yml ]
    )
  end

  connect_to_ollama_server

  it 'can import' do
    expect(chat.import('./spec/assets/example.html')).to start_with(<<~EOT)
      Imported "./spec/assets/example.html":

      # My First Heading

      My first paragraph.
    EOT
  end

  it 'can summarize' do
    expect(chat.summarize('./spec/assets/example.html')).to start_with(<<~EOT)
      Generate an abstract summary of the content in this document using
      100 words:

      # My First Heading

      My first paragraph.
    EOT
  end

  it 'can embed' do
    expect(chat).to receive(:fetch_source).with(
      './spec/assets/example.html'
    )
    expect(chat.embed('./spec/assets/example.html')).to eq(
      'This source was now embedded: ./spec/assets/example.html'
    )
  end

  describe '#fetch_source' do
    context 'with filename' do
      it 'can handle files without spaces' do
        source = './spec/assets/example.html'
        expect(chat).to receive(:fetch_source_as_filename).
          with(File.expand_path(source))
        chat.fetch_source(source)
      end

      it 'can handle files with \\ escaped spaces' do
        source    = './spec/assets/file\ with\ spaces.html'
        unescaped = source.gsub('\ ', ' ')
        expect(chat).to receive(:fetch_source_as_filename).
          with(File.expand_path(unescaped))
        chat.fetch_source(source)
      end

      it 'can handle files with spaces in " quotes' do
        source = '"./spec/assets/file with spaces.html"'
        expect(chat).to receive(:fetch_source_as_filename).
          with(File.expand_path(source[1..-2]))
        chat.fetch_source(source)
      end

      it 'can handle files with spaces and " in " quotes' do
        source = '"./spec/assets/file with \" and spaces.html"'
        expect(chat).to receive(:fetch_source_as_filename).
          with(File.expand_path('./spec/assets/file with " and spaces.html'))
        chat.fetch_source(source)
      end

      it 'handles relative paths correctly' do
        source = '../spec/assets/example.html'
        expect(chat).to receive(:fetch_source_as_filename).
          with(File.expand_path(source))
        chat.fetch_source(source)
      end

      it 'handles tilde expansion in filename' do
        source = '~/test.txt'
        expect(chat).to receive(:fetch_source_as_filename).
          with(File.expand_path(source))
        chat.fetch_source(source)
      end

      it 'handles absolute paths in filename' do
        source = '/tmp/test.txt'
        expect(chat).to receive(:fetch_source_as_filename).
          with(File.expand_path(source))
        chat.fetch_source(source)
      end
    end

    context 'with file:// URI' do
      it 'fetches content from file URI with encoded paths' do
        source = 'file:///path/with%20spaces/file.txt'
        expect(chat).to receive(:fetch_source_as_filename).
          with('/path/with spaces/file.txt')
        chat.fetch_source(source)
      end
    end
  end
end
