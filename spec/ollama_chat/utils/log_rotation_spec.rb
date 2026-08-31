require 'tmpdir'

describe OllamaChat::Utils::LogRotation do
  describe '.truncate_tail' do
    it 'is a no-op when the file does not exist' do
      described_class.truncate_tail('/nonexistent/test.log', keep_lines: 10)
    end

    it 'is a no-op for an empty file' do
      Dir.mktmpdir do |dir|
        log = File.join(dir, 'test.log')
        File.write(log, '')
        described_class.truncate_tail(log, keep_lines: 10)
        expect(File.read(log)).to eq ''
      end
    end

    it 'is a no-op when the file has fewer lines than keep_lines' do
      Dir.mktmpdir do |dir|
        log = File.join(dir, 'test.log')
        File.write(log, "line1\nline2\nline3\n")
        described_class.truncate_tail(log, keep_lines: 10)
        expect(File.read(log)).to eq "line1\nline2\nline3\n"
      end
    end

    it 'is a no-op when the file has exactly keep_lines lines' do
      Dir.mktmpdir do |dir|
        log = File.join(dir, 'test.log')
        File.write(log, (1..10).map { |i| "line #{i}\n" }.join)
        described_class.truncate_tail(log, keep_lines: 10)
        expect(File.read(log).lines.length).to eq 10
      end
    end

    it 'truncates to the last keep_lines lines' do
      Dir.mktmpdir do |dir|
        log = File.join(dir, 'test.log')
        File.write(log, (1..100).map { |i| "line #{i}\n" }.join)
        described_class.truncate_tail(log, keep_lines: 10)
        content = File.read(log)
        lines = content.lines
        expect(lines.length).to eq 10
        expect(lines.first).to eq "line 91\n"
        expect(lines.last).to eq "line 100\n"
      end
    end

    it 'preserves the inode' do
      Dir.mktmpdir do |dir|
        log = File.join(dir, 'test.log')
        File.write(log, (1..100).map { |i| "line #{i}\n" }.join)
        before_ino = File.stat(log).ino
        described_class.truncate_tail(log, keep_lines: 10)
        expect(File.stat(log).ino).to eq before_ino
      end
    end

    it 'handles a file without a trailing newline' do
      Dir.mktmpdir do |dir|
        log = File.join(dir, 'test.log')
        File.write(log, (1..50).map { |i| "line #{i}\n" }.join)
        File.open(log, 'a') { |f| f.puts('final') }
        described_class.truncate_tail(log, keep_lines: 10)
        lines = File.read(log).lines
        expect(lines.length).to eq 10
        expect(lines.last).to eq "final\n"
      end
    end
  end
end
