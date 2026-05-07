describe OllamaChat::Utils::PNGCharacterExtractor do
  let(:extractor) { described_class }

  describe '.extract_character_json' do
    context 'with the actual fluffy.png asset' do
      it 'successfully extracts the character profile for Fluffy McFluffington using IO' do
        asset_io('fluffy.png') do |io|
          json_string = extractor.extract_character_json(io)

          expect(json_string).not_to be_nil

          profile = JSON.parse(json_string)
          expect(profile['name']).to eq 'Fluffy McFluffington'
          expect(profile['personality']).to include 'most important thing in this room'
          expect(profile['first_mes']).to eq 'Mew! Prrr-t!'
        end
      end

      it 'successfully extracts the character profile using a Pathname (triggers binread)' do
        path = asset_pathname('fluffy.png')
        json_string = extractor.extract_character_json(path)

        expect(json_string).not_to be_nil
        expect(JSON.parse(json_string)['name']).to eq 'Fluffy McFluffington'
      end
    end

    context 'with invalid or corrupted data' do
      it 'returns nil for a file that does not contain character data' do
        io = StringIO.new("\x89PNG\r\n\x1a\n" + "dummy data")
        io.binmode
        expect(extractor.extract_character_json(io)).to be_nil
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
        expect(extractor.extract_character_json(io)).to be_nil
      end
    end

    context 'with problematic IO objects' do
      it 'returns nil if the IO object does not respond to binmode or binread' do
        bad_io = double('IO')
        allow(bad_io).to receive(:respond_to?).with(:binmode).and_return(false)
        allow(bad_io).to receive(:respond_to?).with(:binread).and_return(false)

        expect(extractor.extract_character_json(bad_io)).to be_nil
      end
    end
  end
end
