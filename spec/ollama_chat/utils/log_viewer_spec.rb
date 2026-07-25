require 'spec_helper'

describe OllamaChat::Utils::LogViewer do
  describe '.format_line' do
    let(:valid_line) { JSON.generate({
      'time'     => '2026-07-26T03:00:00+02:00',
      'level'    => 'info',
      'progname' => 'ollama_chat',
      'msg'      => 'Test message',
      'data'     => { 'tool' => 'read_file', 'path' => '/tmp/test.txt' }
    }) }

    it 'returns a formatted string containing time, level, progname, and msg' do
      result = described_class.format_line(valid_line)
      expect(result).to include('2026-07-26T03:00:00+02:00')
      expect(result).to include('INFO')
      expect(result).to include('ollama_chat')
      expect(result).to include('Test message')
    end

    it 'includes the data payload when display_data is true' do
      result = described_class.format_line(valid_line, display_data: true)
      expect(result).to include('🪵 data')
    end

    it 'excludes the data payload when display_data is false' do
      result = described_class.format_line(valid_line, display_data: false)
      expect(result).not_to include('🪵 data')
    end

    it 'returns nil for blank lines' do
      expect(described_class.format_line('')).to be_nil
      expect(described_class.format_line(nil)).to be_nil
    end

    context 'with missing optional fields' do
      it 'uses defaults for missing fields without raising' do
        partial_line = JSON.generate({ 'level' => 'warn' })
        expect { described_class.format_line(partial_line) }.not_to raise_error
        result = described_class.format_line(partial_line)
        expect(result).to include('WARN')
      end
    end

    context 'with unknown log levels' do
      it 'defaults to white color without raising' do
        unknown_level_line = JSON.generate({ 'level' => 'trace', 'msg' => 'tracing' })
        expect { described_class.format_line(unknown_level_line) }.not_to raise_error
      end
    end

    context 'with invalid JSON' do
      it 'returns the raw line when no match filter is provided' do
        expect(described_class.format_line('{ invalid json }')).to eq('{ invalid json }')
      end

      it 'returns nil when a match filter is provided' do
        expect(described_class.format_line('{ invalid json }', match: ['level=error'])).to be_nil
      end
    end
  end

  describe '.format_line match filtering' do
    let(:base_line) { JSON.generate({
      'level'    => 'info',
      'msg'      => 'Tool executed',
      'data'     => { 'tool' => 'read_file', 'path' => '/tmp/test.txt' }
    }) }

    it 'returns the formatted line with no match filter' do
      expect(described_class.format_line(base_line)).not_to be_nil
    end

    context 'with key presence match' do
      it 'matches when the key exists in data' do
        expect(described_class.format_line(base_line, match: ['data.tool'])).not_to be_nil
      end

      it 'returns nil when the key does not exist' do
        expect(described_class.format_line(base_line, match: ['data.missing'])).to be_nil
      end
    end

    context 'with substring/value match' do
      it 'matches when value contains the substring' do
        expect(described_class.format_line(base_line, match: ['data.tool=read'])).not_to be_nil
      end

      it 'matches level with = syntax' do
        expect(described_class.format_line(base_line, match: ['level=info'])).not_to be_nil
      end

      it 'returns nil when value does not match' do
        expect(described_class.format_line(base_line, match: ['data.tool=write'])).to be_nil
      end
    end

    context 'with nested path match' do
      let(:nested_line) { JSON.generate({
        'level' => 'debug',
        'data'  => { 'function' => { 'name' => 'patch_file', 'args' => { 'path' => '/foo' } } }
      }) }

      it 'traverses nested hashes' do
        expect(described_class.format_line(nested_line, match: ['data.function.name=patch_file'])).not_to be_nil
      end

      it 'returns nil when nested path does not match' do
        expect(described_class.format_line(nested_line, match: ['data.function.name=read_file'])).to be_nil
      end

      it 'handles key presence at nested path' do
        expect(described_class.format_line(nested_line, match: ['data.function.args.path'])).not_to be_nil
      end
    end

    context 'with multiple match patterns' do
      it 'requires all patterns to match' do
        patterns = ['level=info', 'data.tool=read_file']
        expect(described_class.format_line(base_line, match: patterns)).not_to be_nil
      end

      it 'returns nil if any pattern fails' do
        patterns = ['level=info', 'data.tool=write_file']
        expect(described_class.format_line(base_line, match: patterns)).to be_nil
      end
    end
  end

  describe 'ANSI color output' do
    it 'includes ANSI escape codes for colored output' do
      line = JSON.generate({ 'level' => 'error', 'msg' => 'failed' })
      result = described_class.format_line(line)
      expect(result).to match(/\e\[/)
    end
  end
end
