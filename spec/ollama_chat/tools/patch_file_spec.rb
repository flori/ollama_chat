describe OllamaChat::Tools::PatchFile do
  let(:chat) do
    OllamaChat::Chat.new(argv: chat_default_config)
  end

  connect_to_ollama_server

  let :tool do
    described_class.new.expose
  end

  let :test_file do
    "./tmp/patch_test_#{Tins::Token.new(bits: 128)}.txt"
  end

  it 'can have name' do
    expect(tool.name).to eq 'patch_file'
  end

  it 'can have tool' do
    expect(tool.tool).to be_a Ollama::Tool
  end

  it 'can be converted to hash' do
    expect(tool.to_hash).to be_a Hash
  end

  describe 'coordinate-based patching logic' do
    before do
      File.write(test_file, <<~EOT)
        class User
          def name
            "Florian"
          end

          def age
            30
          end
        end
      EOT
    end

    after do
      File.delete(test_file) if File.exist?(test_file)
    end

    it 'replaces a single line correctly' do
      edits = [{ start_line: 3, end_line: 3, text: '"Miyu"' }]
      result = tool.apply_edits(test_file, edits)
      expect(result).to include('"Miyu"')
      expect(result).not_to include('"Florian"')
    end

    it 'defaults end_line to start_line for implicit single-line replacements' do
      edits = [{ start_line: 3, text: '"Surgical Miyu"' }]
      result = tool.apply_edits(test_file, edits)
      expect(result).to include('"Surgical Miyu"')
      expect(result).not_to include('"Florian"')
    end

    it 'replaces a multi-line block using heredocs' do
      new_block = <<~EOT
        def name
          "Surgical Miyu"
          puts "Precision active!"
        end
      EOT
      # Replace lines 2-4 (the name method)
      edits = [{ start_line: 2, end_line: 4, text: new_block.chomp }]
      result = tool.apply_edits(test_file, edits)
      expect(result).to include('puts "Precision active!"')
    end

    it 'applies multiple edits in reverse order without shifting' do
      edits = [
        { start_line: 2, end_line: 4, text: 'def name; "Top"; end' },
        { start_line: 6, end_line: 8, text: 'def age; 28; end' }
      ]
      result = tool.apply_edits(test_file, edits)
      expect(result).to include('"Top"')
      expect(result).to include('28')
    end

    it 'raises error on overlapping ranges' do
      edits = [
        { start_line: 2, end_line: 4, text: 'A' },
        { start_line: 3, end_line: 5, text: 'B' }
      ]
      expect { tool.apply_edits(test_file, edits) }.to\
        raise_error(OllamaChat::ToolFunctionArgumentError, /Overlapping/)
    end

    it 'raises error on out-of-bounds ranges' do
      edits = [{ start_line: 100, end_line: 101, text: 'Void' }]
      expect { tool.apply_edits(test_file, edits) }.to\
        raise_error(OllamaChat::ToolFunctionArgumentError, /Invalid range/)
    end

    it 'raises error when an edit is missing start_line' do
      edits = [
        { start_line: 2, end_line: 4, text: 'Valid' },
        { text: 'Missing start line' }
      ]
      expect { tool.apply_edits(test_file, edits) }.to\
        raise_error(OllamaChat::ToolFunctionArgumentError, /Edit #2 is missing a start_line/)
    end

    it 'raises error when an edit is missing text' do
      edits = [
        { start_line: 2, end_line: 4, text: 'Valid' },
        { start_line: 23 },
      ]
      expect { tool.apply_edits(test_file, edits) }.to\
        raise_error(OllamaChat::ToolFunctionArgumentError, /Edit #2 is missing its substiution text/)
    end


    it 'raises error when patching line 1 of an empty file' do
      empty_file = test_file
      File.write(empty_file, '')
      text  = 'Initial content'
      edits = [{ start_line: 1, end_line: 1, text: }]
      expect(tool.apply_edits(empty_file, edits)).to eq text
      File.delete(empty_file) if File.exist?(empty_file)
    end
  end

  it 'can be executed successfully with valid edits' do
    const_conf_as('OC::DIFF_TOOL' => Pathname.new(`which true`.chomp))
    File.write(test_file, "Line 1\nLine 2\n")

    edits = [{ start_line: 2, end_line: 2, text: 'Modified Line 2' }]
    mtime = File.mtime(test_file).iso8601(0)
    args_double = double('Arguments', path: test_file, edits: edits, mtime: mtime, line_count: 2)
    tool_call = double('ToolCall', function: double(name: 'patch_file', arguments: args_double))

    tmp_double = double('Tempfile', write: true, flush: true, path: '/tmp/test_patch')
    expect(chat).to receive(:edit_text_block).with(/Modified Line 2/, any_args).and_yield(tmp_double)
    allow(tool).to receive(:system).and_return(true)
    allow(tool).to receive(:digest).and_return 'old', 'new'

    result = tool.execute(tool_call, chat: chat)
    expect(json_object(result).success).to eq true
  ensure
    File.delete(test_file) if File.exist?(test_file)
  end

  it 'can handle execution errors gracefully when edits are missing' do
    args_double = double('Arguments', path: test_file, edits: nil)
    tool_call = double('ToolCall', function: double(name: 'patch_file', arguments: args_double))

    result = tool.execute(tool_call, chat: chat)
    expect(json_object(result).error).to eq 'OllamaChat::ToolFunctionArgumentError'
  end

  it 'can handle execution errors gracefully when path is not allowed' do
    args_double = double('Arguments', path: '/etc/passwd', edits: [])
    tool_call = double('ToolCall', function: double(name: 'patch_file', arguments: args_double))

    result = tool.execute(tool_call, chat: chat)
    expect(json_object(result).error).to eq 'OllamaChat::InvalidPathError'
  end
end
