require 'spec_helper'
require 'tmpdir'
require 'fileutils'

describe OllamaChat::Utils::AnalyzeDirectory do
  let(:generate) { described_class.method(:generate_structure) }

  context 'basic directory structure' do
    before do
      @tmp_dir = Dir.mktmpdir
      @file_a  = File.join(@tmp_dir, 'a.txt')
      @file_b  = File.join(@tmp_dir, 'b.rb')
      @sub_dir = File.join(@tmp_dir, 'sub')
      Dir.mkdir(@sub_dir)
      @file_c  = File.join(@sub_dir, 'c.md')

      File.write(@file_a, 'content a')
      File.write(@file_b, 'content b')
      File.write(@file_c, 'content c')
    end

    after { FileUtils.remove_entry(@tmp_dir) }

    it 'returns an array of hashes describing files and directories' do
      result = generate.call(@tmp_dir)

      expect(result).to be_an(Array)
      expect(result.map { |e| e[:name] }).to contain_exactly('a.txt', 'b.rb', 'sub')

      sub = result.find { |e| e[:name] == 'sub' }
      expect(sub[:type]).to eq('directory')
      expect(sub[:children]).to be_an(Array)
      expect(sub[:children].map { |e| e[:name] }).to contain_exactly('c.md')
    end
  end

  context 'skipping hidden files and symlinks' do
    before do
      @tmp_dir = Dir.mktmpdir
      @hidden  = File.join(@tmp_dir, '.hidden')
      @file    = File.join(@tmp_dir, 'visible.txt')
      @link    = File.join(@tmp_dir, 'link')
      File.write(@hidden, 'secret')
      File.write(@file, 'visible')
      File.symlink(@file, @link)
    end

    after { FileUtils.remove_entry(@tmp_dir) }

    it 'does not include hidden files or symlinks' do
      result = generate.call(@tmp_dir)
      names  = result.map { |e| e[:name] }

      expect(names).not_to include('.hidden')
      expect(names).not_to include('link')
      expect(names).to include('visible.txt')
    end
  end

  context 'exclusion handling' do
    before do
      @tmp_dir = Dir.mktmpdir
      @sub_dir = File.join(@tmp_dir, 'exclude_me')
      Dir.mkdir(@sub_dir)
      @file = File.join(@sub_dir, 'file.txt')
      File.write(@file, 'content')
    end

    after { FileUtils.remove_entry(@tmp_dir) }

    it 'skips directories listed in the exclude list' do
      result = generate.call(@tmp_dir, exclude: [File.join(@tmp_dir, 'exclude_me')])
      names  = result.map { |e| e[:name] }

      expect(names).not_to include('exclude_me')
    end
  end

  context 'error handling' do
    it 'returns a hash with error information when the path is missing' do
      missing = File.join(Dir.tmpdir, 'nonexistent_dir')
      result  = generate.call(missing)

      expect(result).to be_a(Hash)
      expect(result[:error]).to eq(Errno::ENOENT)
      expect(result[:message]).to match(
        /No such file or directory @ dir_initialize/
      )
    end
  end
end
