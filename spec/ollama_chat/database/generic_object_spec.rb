# frozen_string_literal: true

describe OllamaChat::Database::GenericObject do
  describe '.[]' do
    it 'creates an instance from a hash with method access' do
      go = described_class[default: false, content: 'hello']
      expect(go.default).to be(false)
      expect(go.content).to eq('hello')
    end

    it 'creates an empty object with no arguments' do
      expect(described_class[].to_hash).to eq({})
    end
  end

  describe '#to_hash' do
    it 'returns the attribute table as a plain hash' do
      go = described_class[a: 1, b: { c: 2 }]
      hash = go.to_hash
      expect(hash).to eq(a: 1, b: { c: 2 })
      expect(hash).to be_a(Hash)
    end
  end

  describe '#method access (OpenStruct inheritance)' do
    it 'allows read and write of attributes' do
      go = described_class[]
      go.content = 'updated'
      expect(go.content).to eq('updated')
    end

    it 'returns nil for unset attributes' do
      expect(described_class[].missing).to be_nil
    end
  end

  describe '.from_hash' do
    it 'converts a flat hash with symbol keys' do
      go = described_class.from_hash(default: true, content: 'x')
      expect(go.default).to be(true)
      expect(go.content).to eq('x')
    end

    it 'converts string-keyed hashes (as returned by JSON.parse)' do
      go = described_class.from_hash('default' => false, 'content' => 'y')
      expect(go[:default]).to be(false)
      expect(go[:content]).to eq('y')
    end

    it 'recursively converts nested hashes' do
      go = described_class.from_hash(outer: { inner: { deep: true } })
      expect(go.outer.inner.deep).to be(true)
      expect(go.outer.inner).to be_a(described_class)
    end

    it 'maps array elements element-wise' do
      go = described_class.from_hash(list: [{ a: 1 }, { b: 2 }])
      expect(go.list).to all(be_a(described_class))
      expect(go.list[0].a).to eq(1)
      expect(go.list[1].b).to eq(2)
    end

    it 'leaves scalar values unchanged' do
      expect(described_class.from_hash(42)).to eq(42)
      expect(described_class.from_hash('str')).to eq('str')
      expect(described_class.from_hash(nil)).to be_nil
      expect(described_class.from_hash(true)).to be(true)
    end
  end

  describe '.load' do
    it 'parses a JSON object into a GenericObject' do
      go = described_class.load('{"name":"Jane","age":30}')
      expect(go).to be_a(described_class)
      expect(go.name).to eq('Jane')
      expect(go.age).to eq(30)
    end

    it 'returns an empty GenericObject for a nil source' do
      expect(described_class.load(nil)).to eq(described_class[])
    end

    it 'returns an empty GenericObject when JSON parses to nil' do
      expect(described_class.load('null')).to eq(described_class[])
    end

    it 'returns a plain array for a JSON array source' do
      expect(described_class.load('[1,2,3]')).to eq([1, 2, 3])
    end

    # The four stored-JSON shapes the json_go migration must survive.
    # Call sites rely on each_pair yielding symbol-keyed pairs for
    # objects and an empty enumerator for null/empty — this is the
    # contract that keeps trigger&.each_pair&.first working.
    describe 'each_pair shape across all stored-JSON types' do
      it 'yields symbol-keyed pairs for a JSON object' do
        go = described_class.load('{"a":true}')
        expect(go.each_pair.to_a).to eq([[:a, true]])
      end

      it 'yields an empty enumerator for a JSON null' do
        go = described_class.load('null')
        expect(go).to be_a(described_class)
        expect(go.each_pair.to_a).to eq([])
      end

      it 'yields an empty enumerator for a JSON empty object' do
        go = described_class.load('{}')
        expect(go).to be_a(described_class)
        expect(go.each_pair.to_a).to eq([])
      end

      it 'returns a plain Array (not a GenericObject) for a JSON array' do
        result = described_class.load('[1,2,3]')
        expect(result).to be_a(Array)
        expect(result).to eq([1, 2, 3])
      end
    end
  end

  describe '.dump' do
    it 'serializes a GenericObject to a JSON string without a class marker' do
      json = described_class.dump(described_class[hello: 'world'])
      expect(json).to eq('{"hello":"world"}')
      expect(json).not_to include('json_class')
    end

    it 'passes plain hashes through unchanged' do
      expect(described_class.dump({ a: 1 })).to eq('{"a":1}')
    end

    it 'passes arrays through unchanged' do
      expect(described_class.dump([1, 2, 3])).to eq('[1,2,3]')
    end

    it 'passes scalars through unchanged' do
      expect(described_class.dump('str')).to eq('"str"')
    end
  end

  describe 'round-trip' do
    it 'preserves data through dump/load' do
      original = described_class.from_hash(default: true, content: 'x')
      restored = described_class.load(described_class.dump(original))
      expect(restored.default).to be(true)
      expect(restored.content).to eq('x')
    end

    it 'preserves nested structure through dump/load' do
      original = described_class.from_hash(outer: { inner: { deep: [1, 2] } })
      restored = described_class.load(described_class.dump(original))
      expect(restored.outer.inner.deep).to eq([1, 2])
    end
  end

  describe '#as_json' do
    it 'returns a string-keyed hash' do
      go = described_class[default: true, content: 'x']
      expect(go.as_json).to eq('default' => true, 'content' => 'x')
    end
  end

  describe '#to_json' do
    it 'produces string-keyed JSON without a class marker' do
      go = described_class[hello: 'world']
      expect(go.to_json).to eq('{"hello":"world"}')
    end
  end

  describe '#|' do
    it 'merges another object with self winning on conflict' do
      go = described_class[a: 1, b: 2]
      merged = go | described_class[b: 99, c: 3]
      expect(merged.a).to eq(1)
      expect(merged.b).to eq(2)
      expect(merged.c).to eq(3)
    end
  end

  describe 'no json_class marker in serialized output' do
    it 'omits the marker from as_json and to_json' do
      go = described_class[foo: 'bar']
      expect(go.as_json).not_to have_key('json_class')
      expect(go.as_json).not_to have_key(:json_class)
      expect(JSON.parse(go.to_json)).not_to have_key('json_class')
    end
  end
end
