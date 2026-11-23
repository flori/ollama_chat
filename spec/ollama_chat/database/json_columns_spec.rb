# frozen_string_literal: true

describe OllamaChat::Database::JSONColumns do
  GO = OllamaChat::Database::GenericObject

  # An anonymous model bound to the existing `favourites` table. Its
  # `metadata` column is a nullable Text column, which is exactly what
  # the serialization plugin expects. The `around` hook in spec_helper
  # wraps every example in a rolled-back transaction, so nothing
  # persists.
  let(:klass) do
    Sequel::Model(OllamaChat::DB[:favourites]).tap do |model|
      model.class_eval do
        include OllamaChat::Database::JSONColumns
        plugin :serialization, :json_go, :metadata
        json_column :metadata, default: { 'default' => false }
      end
    end
  end

  describe 'reader' do
    it 'returns a GenericObject for a non-nil stored value' do
      klass.create(context: 'ctx', name: 'n1', metadata: { content: 'hello' })
      reloaded = klass.first(name: 'n1')

      expect(reloaded.metadata).to be_a(GO)
      expect(reloaded.metadata.content).to eq('hello')
    end

    it 'supports both method and string-bracket access (compat guarantee)' do
      klass.create(context: 'ctx', name: 'n2', metadata: { content: 'x' })
      reloaded = klass.first(name: 'n2')

      expect(reloaded.metadata.content).to eq('x')
      expect(reloaded.metadata['content']).to eq('x')
    end

    it 'returns a fresh non-nil GenericObject for a nil column with a default' do
      klass.create(context: 'ctx', name: 'n3')
      reloaded = klass.first(name: 'n3')

      first  = reloaded.metadata
      second = reloaded.metadata

      expect(first).to be_a(GO)
      expect(first[:default]).to be(false)
      # Two reads must not share one object (no cross-record mutation).
      expect(first).not_to be(second)
    end
  end

  describe 'writer' do
    it 'coerces a plain symbol-keyed hash to a GenericObject in memory' do
      record = klass.new(context: 'ctx', name: 'w1', metadata: { a: 1 })
      expect(record.metadata).to be_a(GO)
      expect(record.metadata.a).to eq(1)
    end

    it 'coerces the mixed-key GeneratorError shape without raising' do
      mixed = { default: true, content: 'old' }.merge('content' => 'updated')
      # The raw mixed hash is exactly what blows up under json 3.x:
      expect { JSON.generate(mixed) }.to raise_error(JSON::GeneratorError)

      record = klass.new(context: 'ctx', name: 'w2')
      record.metadata = mixed
      record.save

      reloaded = klass.first(name: 'w2')
      expect(reloaded.metadata.content).to eq('updated')
      expect(reloaded.metadata.default).to be(true)
    end

    it 'passes a nil assignment straight through' do
      record = klass.new(context: 'ctx', name: 'w3', metadata: { a: 1 })
      record.metadata = nil
      expect(record.metadata).to be_a(GO) # default fills in
    end
  end

  describe 'persistence round-trip' do
    it 'persists a mutated content value across save/reload' do
      klass.create(context: 'ctx', name: 'r1', metadata: { content: 'old' })
      record = klass.first(name: 'r1')
      record.metadata.content = 'new'
      record.save

      expect(klass.first(name: 'r1').metadata.content).to eq('new')
    end
  end
end
