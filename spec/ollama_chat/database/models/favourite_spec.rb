describe 'OllamaChat::Database::Models::Favourite', type: :model do
  let(:context) { 'test_context' }
  let(:name) { 'test_favourite' }

  describe 'database constraints' do
    it 'enforces uniqueness of context and name' do
      OllamaChat::Database::Models::Favourite.create(
        context:, name:, metadata: { key: 'value' }
      )

      # Attempting to create a duplicate should raise a Sequel error
      expect {
        OllamaChat::Database::Models::Favourite.create(
          context:, name:
        )
      }.to raise_error(Sequel::ValidationFailed)
    end
  end

  describe 'metadata serialization and deserialization' do
    it 'serializes a Hash and deserializes it back as a GenericObject' do
      metadata_payload = { 'theme' => 'dark', 'priority' => 1 }

      # The create call triggers before_save
      fav = OllamaChat::Database::Models::Favourite.create(
        context:, name:, metadata: metadata_payload
      )

      # We reload to trigger after_load
      reloaded_fav = OllamaChat::Database::Models::Favourite.first(id: fav.id)

      expect(reloaded_fav.metadata).to be_a(OllamaChat::Database::GenericObject)
      expect(reloaded_fav.metadata['theme']).to eq('dark')
      expect(reloaded_fav.metadata['priority']).to eq(1)
    end

    it 'raises a ParserError for invalid JSON stored in the column' do
      # We bypass the model to inject invalid JSON directly into the DB
      OllamaChat::DB.run(
        "INSERT INTO favourites (context, name, metadata, created_at, updated_at) " \
        "VALUES ('error_test', 'bad_json', 'not-valid-json{', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
      )

      expect {
        OllamaChat::Database::Models::Favourite.first(name: 'bad_json').metadata
      }.to raise_error(JSON::ParserError)
    end

    it 'returns a GenericObject for hash metadata without a fresh reload' do
      fav = OllamaChat::Database::Models::Favourite.create(
        context:, name:, metadata: { 'already' => 'hash' }
      )

      # Accessing metadata directly without a fresh reload from DB
      # (to ensure we aren't just testing the reload, but the writer path)
      expect(fav.metadata).to be_a(OllamaChat::Database::GenericObject)
      expect(fav.metadata['already']).to eq('hash')
    end
  end

  describe 'update metadata' do
    let!(:fav) do
      OllamaChat::Database::Models::Favourite.create(
        context:, name:, metadata: { 'existing' => 'data' }
      )
    end

    it 'merges new data into the existing metadata' do
      fav.update(metadata: fav.metadata | { 'new_key' => 'new_value' })
      fav.reload

      expect(fav.metadata['existing']).to eq('data')
      expect(fav.metadata['new_key']).to eq('new_value')
    end
  end

  context "nil and non‑hash metadata handling" do
    it "keeps nil metadata after reload" do
      f = OllamaChat::Database::Models::Favourite.create(
        context:, name: "nil_test", metadata: nil
      )
      reload = OllamaChat::Database::Models::Favourite.first(id: f.id)
      expect(reload.metadata).to be_nil
    end

    it "serialises and deserialises an array" do
      arr = %w[foo bar baz]
      f = OllamaChat::Database::Models::Favourite.create(
        context:, name: "array_test", metadata: arr
      )
      reload = OllamaChat::Database::Models::Favourite.first(id: f.id)
      expect(reload.metadata).to eq(arr)
    end
  end
end
