describe OllamaChat::RAGHandling do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config).expose
  end

  connect_to_ollama_server

  let :col_model do
    OllamaChat::Database::Models::Collection
  end

  let :docs do
    double('Documents')
  end

  before do
    chat.instance_variable_set(:@documents, docs)
  end

  describe '#switch_collection' do
    it 'switches, yields the new name, and restores' do
      expect(docs).to receive(:collection).and_return('default')
      expect(docs).to receive(:collection=).with('other')
      expect(docs).to receive(:collection=).with('default')

      expect(chat.switch_collection('other') { |c| c }).to eq 'other'
    end

    it 'uses the current collection when called without arguments' do
      expect(docs).to receive(:collection).twice.and_return('cur')
      expect(docs).to receive(:collection=).with('cur').twice

      expect(chat.switch_collection { :done }).to eq :done
    end

    it 'restores the original collection on exception' do
      expect(docs).to receive(:collection).and_return('d')
      expect(docs).to receive(:collection=).with('x')
      expect(docs).to receive(:collection=).with('d')

      expect { chat.switch_collection('x') { raise 'err' } }
        .to raise_error(RuntimeError, 'err')
    end
  end

  describe '#extract_patterns' do
    it 'returns an empty array for nil' do
      expect(chat.extract_patterns(nil)).to eq []
    end

    it 'splits and expands patterns' do
      expect(chat.extract_patterns('lib/**/*.rb')).to eq [
        File.expand_path('lib/**/*.rb')
      ]
    end

    it 'handles quoted spaces' do
      expect(chat.extract_patterns('"my dir"/*.rb')).to eq [
        File.expand_path('my dir/*.rb')
      ]
    end
  end

  describe '#set_current_collection' do
    it 'sets the collection on documents' do
      expect(docs).to receive(:collection=).with('x')
      chat.set_current_collection('x')
    end
  end

  describe '#database_collection?' do
    it 'returns the record when found' do
      rec = col_model.create(name: 't', description: 'd')
      expect(chat.database_collection?('t')).to eq rec
    end

    it 'returns nil when not found' do
      expect(chat.database_collection?('ghost')).to be_nil
    end
  end

  describe '#all_collections' do
    it 'returns collections ordered by name' do
      col_model.create(name: 'z', description: 'd')
      col_model.create(name: 'a', description: 'd')
      names = chat.all_collections.map(&:name)
      expect(names).to include('a', 'z')
      expect(names).to eq(names.sort)
    end
  end

  describe '#clear_collection' do
    let :docs do
      double('Documents', collection: 'default', tags: %w[ t1 t2 ])
    end

    before do
      expect(chat).to receive(:choose_with_state).and_yield
    end

    it 'exits on [EXIT]' do
      expect(chat).to receive(:choose_entry).and_return('[EXIT]')
      expect(STDOUT).to receive(:puts).with('Exiting chooser.')
      chat.clear_collection
    end

    it 'exits on nil' do
      expect(chat).to receive(:choose_entry).and_return(nil)
      expect(STDOUT).to receive(:puts).with('Exiting chooser.')
      chat.clear_collection
    end

    it 'clears all when [ALL] is confirmed' do
      expect(chat).to receive(:choose_entry).and_return('[ALL]')
      expect(chat).to receive(:confirm?).and_return(true)
      expect(docs).to receive(:clear)
      chat.clear_collection
    end

    it 'clears a single tag then exits' do
      expect(chat).to receive(:choose_entry).
        and_return('t1', '[EXIT]')
      expect(docs).to receive(:clear).with(tags: [ 't1' ])
      expect(STDOUT).to receive(:puts).
        with(a_string_including('Cleared tag t1'))
      expect(STDOUT).to receive(:puts).with('Exiting chooser.')
      chat.clear_collection
    end
  end

  describe '#choose_collection' do
    let :session do
      double('Session')
    end

    before do
      chat.instance_variable_set(:@session, session)
      expect(chat).to receive(:info)
    end

    it 'switches to an existing collection' do
      expect(chat).to receive(:all_collections).
        and_return(double('DS', pluck:  %w[ other ]))
      expect(chat).to receive(:choose_entry).and_return('other')
      expect(docs).to receive(:collection=).with('other')
      expect(session).to receive(:update).
        with(current_collection: 'other')
      chat.choose_collection('default')
    end

    it 'creates a new collection on [NEW]' do
      expect(chat).to receive(:all_collections).
        and_return(double('DS', pluck: []))
      expect(chat).to receive(:choose_entry).and_return('[NEW]')
      expect(chat).to receive(:create_collection).and_return('nc')
      expect(docs).to receive(:collection=).with('nc')
      expect(session).to receive(:update).
        with(current_collection: '[NEW]')
      expect(STDOUT).to receive(:puts).
        with(a_string_including('Using collection'))
      chat.choose_collection('default')
    end

    it 'exits without changing on [EXIT]' do
      expect(chat).to receive(:all_collections).
        and_return(double('DS', pluck: []))
      expect(chat).to receive(:choose_entry).and_return('[EXIT]')
      expect(STDOUT).to receive(:puts).with('Exiting chooser.')
      expect(session).to receive(:update).
        with(current_collection: '[EXIT]')
      expect(STDOUT).to receive(:puts).
        with(a_string_including('Using collection'))
      chat.choose_collection('default')
    end
  end

  describe '#rename_collection' do
    def mock_history
      expect(chat).to receive(:switch_history) do |*, &blk|
        blk.call
      end
    end

    it 'renames and updates the database record' do
      col_model.create(name: 'old', description: 'd')
      mock_history
      expect(chat).to receive(:ask?).and_return('new')
      expect(docs).to receive(:rename_collection).with(:new)
      chat.rename_collection(:old)
      expect(col_model[name: 'new']).not_to be_nil
    end

    it 'cancels when input is blank' do
      mock_history
      expect(chat).to receive(:ask?).and_return(nil)
      expect(STDOUT).to receive(:puts).with('Renaming cancelled.')
      chat.rename_collection(:cur)
    end

    it 'reports unique-constraint violation' do
      col_model.create(name: 'taken', description: 'd')
      mock_history
      expect(chat).to receive(:ask?).and_return('taken')
      expect(docs).to receive(:rename_collection).
        and_raise(Sequel::UniqueConstraintViolation)
      expect(STDERR).to receive(:puts).
        with(a_string_including('already exists in database'))
      chat.rename_collection(:old)
    end

    it 'reports generic errors' do
      mock_history
      expect(chat).to receive(:ask?).and_return('bad')
      expect(docs).to receive(:rename_collection).
        and_raise(StandardError, 'oops')
      expect(STDERR).to receive(:puts).
        with(a_string_including('oops'))
      chat.rename_collection(:old)
    end
  end

  describe '#list_collections' do
    it 'prints each collection name and description' do
      col_model.create(name: 'cur', description: 'active')
      col_model.create(name: 'oth', description: 'inactive')

      expect(docs).to receive(:collection).and_return('cur')
      buf = StringIO.new
      expect(chat).to receive(:use_pager).and_yield(buf)

      chat.list_collections
      expect(buf.string).to include('cur')
      expect(buf.string).to include('active')
      expect(buf.string).to include('oth')
    end
  end

  describe '#update_collection' do
    it 'reports when the collection is not in the database' do
      expect(chat).to receive(:switch_collection).with('nope').and_yield
      expect(chat).to receive(:database_collection?).and_return(nil)
      expect(STDERR).to receive(:puts).
        with(a_string_including('not found in database'))
      chat.update_collection('nope')
    end

    context 'with a valid collection' do
      let :col do
        col_model.create(name: 'tc', description: 'd', patterns: [])
      end
      let :rec do
        double('Record', source: 'a.rb', tags_set: %w[ t1 ])
      end

      it 're-embeds modified sources' do
        expect(chat).to receive(:switch_collection).with('tc').and_yield
        expect(chat).to receive(:database_collection?).and_return(col)
        expect(docs).to receive(:each_record).and_yield(rec)
        expect(docs).to receive(:normalize_source).
          with('a.rb').and_return('a.rb')
        expect(docs).to receive(:source_modified?).
          with('a.rb').and_return(true)
        expect(docs).to receive(:source_remove).with('a.rb')
        expect(chat).to receive(:embed).
          with('a.rb', tags: %w[ t1 ]).and_return('Embedded a.rb')

        expect(chat.update_collection('tc')).to eq 'Embedded a.rb'
      end

      it 'skips unmodified sources' do
        expect(chat).to receive(:switch_collection).with('tc').and_yield
        expect(chat).to receive(:database_collection?).and_return(col)
        expect(docs).to receive(:each_record).and_yield(rec)
        expect(docs).to receive(:normalize_source).
          with('a.rb').and_return('a.rb')
        expect(docs).to receive(:source_modified?).
          with('a.rb').and_return(false)

        expect(chat.update_collection('tc')).to eq ''
      end

      it 'embeds new files matching patterns' do
        col.update(patterns: [ File.expand_path('n.rb') ])
        file = Pathname.new(File.expand_path('n.rb'))

        expect(chat).to receive(:switch_collection).with('tc').and_yield
        expect(chat).to receive(:database_collection?).
          and_return(col_model[name: 'tc'])
        expect(docs).to receive(:each_record)
        expect(chat).to receive(:all_file_set).and_return(Set[ file ])
        expect(chat).to receive(:embed).
          with(file.to_s, tags: []).and_return('Embedded n.rb')

        expect(chat.update_collection('tc')).to eq 'Embedded n.rb'
      end
    end
  end

  describe '#create_collection' do
    it 'creates a new collection with all fields' do
      expect(chat).to receive(:switch_history).exactly(3).times do |*, &blk|
        blk.call
      end
      expect(chat).to receive(:ask?).and_return(
        'mycol',            # name
        'My description',   # description
        'lib/**/*.rb',      # patterns
      )
      expect(chat).to receive(:update_collection).with('mycol')

      expect { chat.create_collection }
        .to change { col_model.count }.by(1)

      col = col_model[name: 'mycol']
      expect(col.description).to eq 'My description'
      expect(col.patterns).to eq [ File.expand_path('lib/**/*.rb') ]
    end

    it 'cancels when name is blank' do
      expect(chat).to receive(:switch_history).and_yield
      expect(chat).to receive(:ask?).and_return(nil)
      expect(STDERR).to receive(:puts).
        with(a_string_including('Cancelled creation'))
      expect(chat.create_collection).to be_nil
    end

    it 'rejects an already-existing name' do
      col_model.create(name: 'dup', description: 'd')
      expect(chat).to receive(:switch_history).and_yield
      expect(chat).to receive(:ask?).and_return('dup')
      expect(STDERR).to receive(:puts).
        with(a_string_including('already exists'))
      chat.create_collection
    end

    it 'cancels when description is blank' do
      expect(chat).to receive(:switch_history).exactly(2).times do |*, &blk|
        blk.call
      end
      expect(chat).to receive(:ask?).and_return(
        'mycol',  # name
        nil,      # description (blank)
      )
      expect(STDERR).to receive(:puts).
        with(a_string_including('Cancelled creation of collection'))
      chat.create_collection
    end

    it 'skips update_collection when patterns are empty' do
      expect(chat).to receive(:switch_history).exactly(3).times do |*, &blk|
        blk.call
      end
      expect(chat).to receive(:ask?).and_return(
        'nopat',     # name
        'No patterns', # description
        '',           # empty patterns
      )
      expect { chat.create_collection }
        .to change { col_model.count }.by(1)
    end

    it 'handles database errors on create' do
      expect(chat).to receive(:switch_history).exactly(3).times do |*, &blk|
        blk.call
      end
      expect(chat).to receive(:ask?).and_return('errcol', 'd', '')
      expect(col_model).to receive(:create).
        and_raise(Sequel::Error, 'db down')
      expect(STDERR).to receive(:puts).
        with(a_string_including('Database error'))
      chat.create_collection
    end
  end

  describe '#edit_collection' do
    it 'cancels on [CANCEL]' do
      expect(chat).to receive(:choose_entry).and_return('[CANCEL]')
      chat.edit_collection
    end

    it 'cancels on nil' do
      expect(chat).to receive(:choose_entry).and_return(nil)
      chat.edit_collection
    end

    it 'reports when collection is not in the database' do
      expect(chat).to receive(:choose_entry).and_return('ghost')
      expect(STDERR).to receive(:puts).
        with(a_string_including('not found in database'))
      chat.edit_collection
    end

    it 'updates description and patterns' do
      col_model.create(
        name: 'editme', description: 'old', patterns: []
      )
      expect(chat).to receive(:choose_entry).and_return('editme')
      expect(chat).to receive(:switch_history).exactly(2).times do |*, &blk|
        blk.call
      end
      expect(chat).to receive(:ask?).and_return(
        'new desc',             # description
        'lib/**/*.rb spec/*',   # patterns
      )

      chat.edit_collection

      col = col_model[name: 'editme']
      expect(col.description).to eq 'new desc'
      expect(col.patterns).to include(File.expand_path('lib/**/*.rb'))
    end

    it 'keeps the old description when input is blank' do
      col_model.create(
        name: 'keep', description: 'original', patterns: []
      )
      expect(chat).to receive(:choose_entry).and_return('keep')
      expect(chat).to receive(:switch_history).exactly(2).times do |*, &blk|
        blk.call
      end
      expect(chat).to receive(:ask?).and_return(
        nil,  # blank description
        '',   # empty patterns
      )

      chat.edit_collection

      expect(col_model[name: 'keep'].description).to eq 'original'
    end

    it 'handles database errors on save' do
      col_model.create(
        name: 'errcol', description: 'd', patterns: []
      )
      expect(chat).to receive(:choose_entry).and_return('errcol')
      expect(chat).to receive(:switch_history).exactly(2).times do |*, &blk|
        blk.call
      end
      expect(chat).to receive(:ask?).and_return('new d', '')
      expect_any_instance_of(col_model).to receive(:save).
        and_raise(Sequel::Error, 'db error')
      expect(STDERR).to receive(:puts).
        with(a_string_including('Database error'))

      chat.edit_collection
    end
  end

  describe '#delete_collection' do
    before do
      expect(chat).to receive(:choose_with_state).and_yield
    end

    it 'exits on [CANCEL]' do
      expect(chat).to receive(:choose_entry).and_return('[CANCEL]')
      chat.delete_collection
    end

    it 'exits on nil' do
      expect(chat).to receive(:choose_entry).and_return(nil)
      chat.delete_collection
    end

    it 'reports when collection is not in the database' do
      expect(chat).to receive(:choose_entry).
        and_return('ghost', '[CANCEL]')
      expect(STDERR).to receive(:puts).
        with(a_string_including('not found in database'))
      chat.delete_collection
    end

    it 'deletes the collection when confirmed' do
      col_model.create(name: 'del', description: 'd', patterns: [])
      expect(chat).to receive(:choose_entry).and_return('del', '[CANCEL]')
      expect(chat).to receive(:confirm?).and_return(true)

      # after_destroy → switch_collection + documents.clear
      expect(docs).to receive(:collection).and_return('default')
      expect(docs).to receive(:collection=).with('del')
      expect(docs).to receive(:clear)
      expect(docs).to receive(:collection=).with('default')

      expect { chat.delete_collection }
        .to change { col_model.count }.by(-1)
    end

    it 'skips deletion when declined' do
      col_model.create(name: 'stay', description: 'd', patterns: [])
      expect(chat).to receive(:choose_entry).
        and_return('stay', '[CANCEL]')
      expect(chat).to receive(:confirm?).and_return(false)
      expect(STDOUT).to receive(:puts).with('🚫 Deletion cancelled.')

      expect { chat.delete_collection }
        .not_to change { col_model.count }
    end
  end
end
