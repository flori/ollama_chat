describe OllamaChat::ModelHandling do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config).expose
  end

  connect_to_ollama_server

  it 'can check if model_present? false' do
    expect(chat.ollama).to receive(:show).and_raise Ollama::Errors::NotFoundError
    expect(chat.model_present?('nixda')).to eq nil
  end

  it 'can check if model_present? true' do
    stub_request(:post, %r(/api/show\z)).
      to_return(status: 200, body: asset_json('api_show.json'))
    model_metadata = chat.model_present?('llama3.1')
    expect(model_metadata.name).to eq 'llama3.1'
    expect(model_metadata.capabilities).to eq %w[ completion tools ]
  end

  it 'can pull_model_unless_present' do
    expect(chat).to receive(:model_present?).with('llama3.1').and_return false
    expect(chat).to receive(:model_present?).with('llama3.1').and_return true
    expect(chat).to receive(:pull_model_from_remote).with('llama3.1')
    expect(chat.pull_model_unless_present('llama3.1')).to eq true
  end

  describe '#export_model_options' do
    before do
      chat.store_model_options('llama3.1', { num_predict: 100 }, profile: 'default')
      chat.store_model_options('llama3.1', { num_predict: 200 }, profile: 'coding')
      chat.store_model_options('mistral', { temperature: 0.7 }, profile: 'default')
    end

    it 'exports all models to file and returns the filename' do
      filename = Pathname.new('tmp/export_test.json')
      allow(chat).to receive(:determine_valid_output_filename).and_return filename
      expect(chat.export_model_options).to eq filename
      data   = JSON.parse(filename.read)
      expect(data).to be_an(Array)
      models = data.index_by { |m| m['model_name'] }
      expect(models).to have_key('llama3.1')
      expect(models).to have_key('mistral')
      expect(models['llama3.1']['profiles'].size).to eq 2
      expect(models['mistral']['profiles'].size).to eq 1
      llama_profiles = models['llama3.1']['profiles'].index_by { |p| p['profile'] }
      expect(llama_profiles['default']['options']).to eq({ 'num_predict' => 100 })
      expect(llama_profiles['coding']['options']).to eq({ 'num_predict' => 200 })
    ensure
      filename&.delete if filename&.exist?
    end

    it 'returns nil when filename selection is cancelled' do
      allow(chat).to receive(:determine_valid_output_filename).and_return nil
      expect(chat.export_model_options).to be nil
    end
  end

  describe '#import_model_options' do
    let(:filename) { Pathname.new('tmp/import_test.json') }

    after do
      filename&.delete if filename&.exist?
    end

    before do
      filename.dirname.mkpath
    end

    def write_import_data(data)
      filename.write(JSON.generate(data))
    end

    it 'imports a single model with multiple profiles' do
      write_import_data([
        { model_name: 'llama3.1', profiles: [
          { profile: 'default', options: { num_predict: 100 } },
          { profile: 'coding',  options: { num_predict: 200 } },
        ]},
      ])
      expect(chat.import_model_options(filename)).to eq true
      expect(chat.get_stored_model_options('llama3.1', profile: 'default'))
        .to eq(num_predict: 100)
      expect(chat.get_stored_model_options('llama3.1', profile: 'coding'))
        .to eq(num_predict: 200)
    end

    it 'lets user pick a model when multiple are present' do
      write_import_data([
        { model_name: 'llama3.1', profiles: [
          { profile: 'default', options: { num_predict: 100 } } ]},
        { model_name: 'mistral', profiles: [
          { profile: 'default', options: { temperature: 0.7 } } ]},
      ])
      allow(chat).to receive(:choose_entry).and_return 'mistral'
      expect(chat.import_model_options(filename)).to eq true
      expect(chat.get_stored_model_options('mistral', profile: 'default'))
        .to eq(temperature: 0.7)
      expect(chat.get_stored_model_options('llama3.1', profile: 'default'))
        .to be_empty
    end

    it 'imports all models when [ALL] is selected' do
      write_import_data([
        { model_name: 'llama3.1', profiles: [
          { profile: 'default', options: { num_predict: 100 } } ]},
        { model_name: 'mistral', profiles: [
          { profile: 'default', options: { temperature: 0.7 } } ]},
      ])
      allow(chat).to receive(:choose_entry).and_return '[ALL]'
      expect(chat.import_model_options(filename)).to eq true
      expect(chat.get_stored_model_options('llama3.1', profile: 'default'))
        .to eq(num_predict: 100)
      expect(chat.get_stored_model_options('mistral', profile: 'default'))
        .to eq(temperature: 0.7)
    end

    it 'skips identical profiles without prompting' do
      chat.store_model_options('llama3.1', { num_predict: 100 }, profile: 'default')
      write_import_data([
        { model_name: 'llama3.1', profiles: [
          { profile: 'default', options: { num_predict: 100 } } ]},
      ])
      expect(chat).not_to receive(:confirm?)
      expect(chat.import_model_options(filename)).to eq true
    end

    it 'shows diff and skips when override is declined' do
      chat.store_model_options('llama3.1', { num_predict: 99 }, profile: 'default')
      write_import_data([
        { model_name: 'llama3.1', profiles: [
          { profile: 'default', options: { num_predict: 200 } } ]},
      ])
      allow(chat).to receive(:confirm?).and_return false
      expect(chat.import_model_options(filename)).to eq true
      expect(chat.get_stored_model_options('llama3.1', profile: 'default'))
        .to eq(num_predict: 99)
    end

    it 'overrides when confirmed' do
      chat.store_model_options('llama3.1', { num_predict: 99 }, profile: 'default')
      write_import_data([
        { model_name: 'llama3.1', profiles: [
          { profile: 'default', options: { num_predict: 200 } } ]},
      ])
      allow(chat).to receive(:confirm?).and_return true
      expect(chat.import_model_options(filename)).to eq true
      expect(chat.get_stored_model_options('llama3.1', profile: 'default'))
        .to eq(num_predict: 200)
    end

    it 'returns nil on invalid format' do
      filename.write(JSON.generate(model_name: 'x', options: {}))
      expect(chat.import_model_options(filename)).to be nil
    end

    it 'cancels when user selects [EXIT]' do
      write_import_data([
        { model_name: 'a', profiles: [{ profile: 'd', options: {} }] },
        { model_name: 'b', profiles: [{ profile: 'd', options: {} }] },
      ])
      allow(chat).to receive(:choose_entry).and_return '[EXIT]'
      expect(chat.import_model_options(filename)).to be nil
    end
  end
end
