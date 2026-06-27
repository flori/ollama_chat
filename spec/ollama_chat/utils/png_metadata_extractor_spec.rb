describe OllamaChat::Utils::PNGMetadataExtractor do
  let(:extractor) { described_class }

  describe '.extract_character' do
    context 'with the actual fluffy.png asset' do
      it 'successfully extracts the character profile for Fluffy McFluffington using IO' do
        asset_io('fluffy.png') do |io|
          json_string = extractor.extract_character(io)

          expect(json_string).not_to be_nil

          profile = JSON.parse(json_string)
          expect(profile['name']).to eq 'Fluffy McFluffington'
          expect(profile['personality']).to include 'most important thing in this room'
          expect(profile['first_mes']).to eq 'Mew! Prrr-t!'
        end
      end

      it 'successfully extracts the character profile using a Pathname (triggers binread)' do
        path = asset_pathname('fluffy.png')
        json_string = extractor.extract_character(path)

        expect(json_string).not_to be_nil
        expect(JSON.parse(json_string)['name']).to eq 'Fluffy McFluffington'
      end
    end

    context 'with invalid or corrupted data' do
      it 'returns nil for a file that does not contain character data' do
        io = StringIO.new("\x89PNG\r\n\x1a\n" + "dummy data")
        io.binmode
        expect(extractor.extract_character(io)).to be_nil
      end

      it 'returns nil when the chara chunk contains invalid Base64 or JSON' do
        # Construct a fake PNG with a 'chara' tEXt chunk containing garbage
        # Signature (8) + Length (4) + Type (4) + Data (Keyword + NULL + Garbage) + CRC (4)
        garbage_data = "chara\x00Not-Valid-Base64-JSON-At-All!"
        binary_blob = "\x89PNG\r\n\x1a\n" +
                      [garbage_data.bytesize].pack('L>') +
                      'tEXt' +
                      garbage_data +
                      [0].pack('L>')

        io = StringIO.new(binary_blob)
        io.binmode
        expect(extractor.extract_character(io)).to be_nil
      end
    end

    context 'with problematic IO objects' do
      it 'returns nil if the IO object does not respond to binmode or binread' do
        bad_io = double('IO')
        allow(bad_io).to receive(:ask_and_send).with(:rewind).and_return(nil)
        allow(bad_io).to receive(:respond_to?).with(:binmode).and_return(false)
        allow(bad_io).to receive(:respond_to?).with(:binread).and_return(false)

        expect(extractor.extract_character(bad_io)).to be_nil
      end
    end
  end

  it 'returns nil if no metadata is found' do
    io = StringIO.new("\x89PNG\r\n\x1a\n" + "no metadata here")
    io.binmode
    expect(extractor.extract_all(io)).to be_nil
  end

  describe 'extract prompt' do
    context 'with the miyu.png asset' do
      it 'successfully extracts the ComfyUI prompt JSON' do
        asset_io('miyu.png') do |io|
          prompt = extractor.extract_all(io)['prompt']
          expect(prompt).not_to be_nil
          expect(prompt).to include('Full-body anime character illustration of Miyu')
        end
      end
    end

    it 'successfully extracts a prompt from tEXt chunk' do
      # Signature (8) + Length (4) + Type (4) + Data (Keyword + NULL + Text) + CRC (4)
      prompt_text = "a beautiful sunset, 8k resolution"
      data = "prompt\x00#{prompt_text}"
      binary_blob = "\x89PNG\r\n\x1a\n" +
                    [data.bytesize].pack('L>') +
                    'tEXt' +
                    data +
                    [0].pack('L>')

      io = StringIO.new(binary_blob)
      io.binmode
      expect(extractor.extract_all(io)['prompt']).to eq prompt_text
    end
  end

  describe 'extract workflow' do
    context 'with the miyu.png asset' do
      it 'successfully extracts the ComfyUI workflow JSON' do
        asset_io('miyu.png') do |io|
          workflow = extractor.extract_all(io)['workflow']
          expect(workflow).not_to be_nil
          expect(workflow).to include('"id": "9ae6082b-c7f4-433c-9971-7a8f65a3ea65"')
        end
      end
    end

    it 'successfully extracts a workflow from tEXt chunk' do
      # Signature (8) + Length (4) + Type (4) + Data (Keyword + NULL + Text) + CRC (4)
      workflow_json = '{"last_node_id": 10, "nodes": []}'
      data = "workflow\x00#{workflow_json}"
      binary_blob = "\x89PNG\r\n\x1a\n" +
                    [data.bytesize].pack('L>') +
                    'tEXt' +
                    data +
                    [0].pack('L>')

      io = StringIO.new(binary_blob)
      io.binmode
      expect(extractor.extract_all(io)['workflow']).to eq workflow_json
    end
  end
end
