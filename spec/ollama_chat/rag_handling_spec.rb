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

  describe '#set_documents_collection' do
    it 'sets the collection on documents' do
      expect(docs).to receive(:collection=).with('x')
      chat.set_documents_collection('x')
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

  describe '#clear_whole_collection' do
    it 'clears all documents and returns self when confirmed' do
      expect(chat).to receive(:confirm?).and_return(true)
      expect(docs).to receive(:collection).twice.and_return('default')
      expect(docs).to receive(:clear)
      expect(chat).to receive(:feedback)
        .with(a_string_including('Cleared collection'), type: :info)
      expect(chat.clear_whole_collection).to eq chat
    end

    it 'returns nil and reports denied when declined' do
      expect(chat).to receive(:confirm?).and_return(false)
      expect(docs).not_to receive(:clear)
      expect(chat).to receive(:feedback).with('Denied.', type: :denied)
      expect(chat.clear_whole_collection).to be_nil
    end
  end

  describe '#clear_collection_tags' do
    before do
      expect(chat).to receive(:choose_with_state).and_yield
    end

    it 'exits on [EXIT]' do
      expect(docs).to receive(:tags).and_return(%w[ t1 ])
      expect(chat).to receive(:choose_entry).and_return('[EXIT]')
      expect(chat).to receive(:feedback).with('Exiting chooser.')
      chat.clear_collection_tags
    end

    it 'exits on nil' do
      expect(docs).to receive(:tags).and_return(%w[ t1 ])
      expect(chat).to receive(:choose_entry).and_return(nil)
      expect(chat).to receive(:feedback).with('Exiting chooser.')
      chat.clear_collection_tags
    end

    context 'single record, no source (memory)' do
      let :rec do
        double('Record', source: nil, text: 'hello world')
      end

      it 'views record and clears via clear(tags:) on c' do
        expect(docs).to receive(:tags).at_least(:once).
          and_return(%w[ mem ])
        expect(chat).to receive(:choose_entry).and_return('mem', '[EXIT]')
        expect(docs).to receive(:records).with(tags: 'mem').
          and_return([ rec ])
        expect(chat).to receive(:feedback).
          with(a_string_including('hello world'), type: :info)
        buf = StringIO.new
        expect(chat).to receive(:use_pager).and_yield(buf)
        expect(chat).to receive(:confirm?).and_return('c')
        expect(docs).to receive(:collection).at_least(:once).
          and_return('default')
        expect(docs).to receive(:clear).with(tags: [ 'mem' ])
        expect(chat).to receive(:log)
        expect(chat).to receive(:feedback)
          .with(a_string_including('Cleared tag mem'), type: :info)
        expect(chat).to receive(:feedback).with('Exiting chooser.')
        chat.clear_collection_tags
        expect(buf.string).to include('hello world')
      end

      it 'views record and goes back on other input' do
        expect(docs).to receive(:tags).at_least(:once).
          and_return(%w[ mem ])
        expect(chat).to receive(:choose_entry).
          and_return('mem', '[EXIT]')
        expect(docs).to receive(:records).with(tags: 'mem').
          and_return([ rec ])
        expect(chat).to receive(:feedback).
          with(a_string_including('hello world'), type: :info)
        buf = StringIO.new
        expect(chat).to receive(:use_pager).and_yield(buf)
        expect(chat).to receive(:confirm?).and_return('x')
        expect(chat).to receive(:feedback).with('Exiting chooser.')
        chat.clear_collection_tags
        expect(buf.string).to include('hello world')
      end
    end

    context 'single record, with source' do
      let :rec do
        double('Record', source: 'a.rb', text: 'hello')
      end

      it 'views record and clears via source_remove on c' do
        expect(docs).to receive(:tags).at_least(:once).
          and_return(%w[ t1 ])
        expect(chat).to receive(:choose_entry).and_return('t1', '[EXIT]')
        expect(docs).to receive(:records).with(tags: 't1').
          and_return([ rec ])
        expect(chat).to receive(:feedback).
          with(a_string_including('a.rb'), type: :info)
        buf = StringIO.new
        expect(chat).to receive(:use_pager).and_yield(buf)
        expect(chat).to receive(:confirm?).and_return('c')
        expect(docs).to receive(:collection).at_least(:once).
          and_return('default')
        expect(docs).to receive(:source_remove).with('a.rb')
        expect(chat).to receive(:log)
        expect(chat).to receive(:feedback)
          .with(a_string_including('Cleared tag t1'), type: :info)
        expect(chat).to receive(:feedback).with('Exiting chooser.')
        chat.clear_collection_tags
        expect(buf.string).to include('hello')
      end
    end

    context 'multi-record, grouped by source' do
      let :rec1 do
        double('Record', source: 'a.rb', text: 'aaa', tags: %w[ t1 ])
      end
      let :rec2 do
        double('Record', source: 'b.rb', text: 'bbb', tags: %w[ t1 ])
      end

      it 'shows source groups and clears picked source' do
        expect(docs).to receive(:tags).at_least(:once).
          and_return(%w[ t1 ])
        expect(chat).to receive(:choose_entry).
          and_return('t1', 'a.rb "aaa"', '[EXIT]')
        expect(docs).to receive(:records).with(tags: 't1').
          and_return([ rec1, rec2 ])
        expect(chat).to receive(:confirm?).and_return('c')
        expect(docs).to receive(:collection).at_least(:once).
          and_return('default')
        expect(docs).to receive(:source_remove).with('a.rb')
        expect(chat).to receive(:log)
        expect(chat).to receive(:feedback)
          .with(a_string_including('Cleared tag t1'), type: :info)
        expect(chat).to receive(:feedback).with('Exiting chooser.')
        chat.clear_collection_tags
      end

      it 'goes back on [back]' do
        expect(docs).to receive(:tags).at_least(:once).
          and_return(%w[ t1 ])
        expect(chat).to receive(:choose_entry).
          and_return('t1', '[back]', '[EXIT]')
        expect(docs).to receive(:records).with(tags: 't1').
          and_return([ rec1, rec2 ])
        expect(chat).to receive(:feedback).with('Exiting chooser.')
        chat.clear_collection_tags
      end
    end
  end

  describe '#clear_collection_sources' do
    before do
      expect(chat).to receive(:choose_with_state).and_yield
    end

    it 'exits on [EXIT]' do
      expect(docs).to receive(:records).and_return([])
      expect(chat).to receive(:choose_entry).and_return('[EXIT]')
      expect(chat).to receive(:feedback).with('Exiting chooser.')
      chat.clear_collection_sources
    end

    it 'exits on nil' do
      expect(docs).to receive(:records).and_return([])
      expect(chat).to receive(:choose_entry).and_return(nil)
      expect(chat).to receive(:feedback).with('Exiting chooser.')
      chat.clear_collection_sources
    end

    it 'clears a source on c' do
      rec = double('Record', source: 'a.rb', text: 'hello',
                   tags: %w[ t1 ])
      expect(docs).to receive(:records).at_least(:once).
        and_return([ rec ])
      expect(chat).to receive(:choose_entry).and_return('a.rb  [t1]', '[EXIT]')
      expect(chat).to receive(:confirm?).and_return('c')
      expect(docs).to receive(:collection).at_least(:once).
        and_return('default')
      expect(docs).to receive(:source_remove).with('a.rb')
      expect(chat).to receive(:log)
      expect(chat).to receive(:feedback)
        .with(a_string_including('Removed source a.rb'), type: :info)
      expect(chat).to receive(:feedback).with('Exiting chooser.')
      chat.clear_collection_sources
    end

    it 'views in pager on v' do
      rec = double('Record', source: 'a.rb', text: 'hello',
                   tags: %w[ t1 ])
      expect(docs).to receive(:records).at_least(:once).
        and_return([ rec ])
      expect(chat).to receive(:choose_entry).and_return('a.rb  [t1]', '[EXIT]')
      expect(chat).to receive(:confirm?).and_return('v')

      buf = StringIO.new
      expect(chat).to receive(:use_pager).and_yield(buf)
      chat.clear_collection_sources
      expect(buf.string).to include('hello')
    end

    it 'goes back on other input' do
      rec = double('Record', source: 'a.rb', text: 'hello',
                   tags: %w[ t1 ])
      expect(docs).to receive(:records).at_least(:once).
        and_return([ rec ])
      expect(chat).to receive(:choose_entry).
        and_return('a.rb  [t1]', '[EXIT]')
      expect(chat).to receive(:confirm?).and_return('x')
      expect(chat).to receive(:feedback).with('Exiting chooser.')
      chat.clear_collection_sources
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
      expect(chat).to receive(:feedback).with(a_string_including('Using collection'), type: :info)
      chat.choose_collection('default')
    end

    it 'exits without changing on [EXIT]' do
      expect(chat).to receive(:all_collections).
        and_return(double('DS', pluck: []))
      expect(chat).to receive(:choose_entry).and_return('[EXIT]')
      expect(chat).to receive(:feedback).with('Exiting chooser.')
      expect(session).to receive(:update).
        with(current_collection: '[EXIT]')
      expect(chat).to receive(:feedback).
        with(a_string_including('Using collection'), type: :info)
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
      expect(chat).to receive(:feedback).with('Renaming cancelled.', type: :cancel)
      chat.rename_collection(:cur)
    end

    it 'reports unique-constraint violation' do
      col_model.create(name: 'taken', description: 'd')
      mock_history
      expect(chat).to receive(:ask?).and_return('taken')
      expect(docs).to receive(:rename_collection).
        and_raise(Sequel::UniqueConstraintViolation)
      expect(chat).to receive(:feedback).
        with(a_string_including('already exists in database'), type: :warn)
      chat.rename_collection(:old)
    end

    it 'reports generic errors' do
      mock_history
      expect(chat).to receive(:ask?).and_return('bad')
      expect(docs).to receive(:rename_collection).
        and_raise(StandardError, 'oops')
      expect(chat).to receive(:feedback).
        with(a_string_including('oops'), type: :warn)
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
      expect(chat).to receive(:feedback).
        with(a_string_including('not found in database'), type: :warn)
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
          with('a.rb', prompt: anything, tags: %w[ t1 ]).and_return('Embedded a.rb')

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
        expect(chat).to receive(:all_file_set).twice.and_return(Set[ file ])
        expect(chat).to receive(:embed).
          with(file.to_s, prompt: anything, tags: []).and_return('Embedded n.rb')

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
      expect(chat).to receive(:feedback).
        with(a_string_including('Cancelled creation'), type: :cancel)
      expect(chat.create_collection).to be_nil
    end

    it 'rejects an already-existing name' do
      col_model.create(name: 'dup', description: 'd')
      expect(chat).to receive(:switch_history).and_yield
      expect(chat).to receive(:ask?).and_return('dup')
      expect(chat).to receive(:feedback).
        with(a_string_including('already exists'), type: :warn)
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
      expect(chat).to receive(:feedback).
        with(a_string_including('Cancelled creation of collection'), type: :cancel)
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
      expect(chat).to receive(:feedback).
        with(a_string_including('Database error'), type: :warn)
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
      expect(chat).to receive(:feedback).
        with(a_string_including('not found in database'), type: :warn)
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
      expect(chat).to receive(:confirm?).and_return(false)

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
      expect(chat).to receive(:confirm?).and_return(false)

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
      expect(chat).to receive(:confirm?).and_return(false)
      expect_any_instance_of(col_model).to receive(:save).
        and_raise(Sequel::Error, 'db error')
      expect(chat).to receive(:feedback).
        with(a_string_including('Database error'), type: :warn)

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
      expect(chat).to receive(:feedback).
        with(a_string_including('not found in database'), type: :warn)
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
      expect(chat).to receive(:feedback).with('Deletion denied.', type: :denied)

      expect { chat.delete_collection }
        .not_to change { col_model.count }
    end
  end

  describe '#create_memory_collection' do
    it 'prepends memory- to a bare persona stem' do
      expect(chat.create_memory_collection('flori')).to eq 'memory-flori'
      expect(col_model[name: 'memory-flori']).not_to be_nil
    end

    it 'uses a full memory- name as-is' do
      expect(chat.create_memory_collection('memory-flori')).to eq 'memory-flori'
      expect(col_model[name: 'memory-flori']).not_to be_nil
    end
  end

  describe '#memory_dump' do
    it 'warns and stops when the collection query yields no list' do
      expect(chat).to receive(:all_collections)
        .and_return(double('DS', where: double('DS2', pluck: nil)))
      expect(chat).to receive(:feedback)
        .with(a_string_including('No memory-* collections found'), type: :warn)
      expect(chat).not_to receive(:choose_with_state)
      chat.memory_dump('x.jsonl')
    end

    it 'cancels when the user selects nothing' do
      expect(chat).to receive(:all_collections)
        .and_return(double('DS', where: double('DS2', pluck: %w[ memory-a ])))
      expect(chat).to receive(:choose_with_state).and_yield
      expect(chat).to receive(:choose_entry).and_return('[DONE]')
      expect(chat).to receive(:feedback)
        .with(a_string_including('Cancelled, no collections selected'), type: :cancel)
      chat.memory_dump('x.jsonl')
    end

    it 'writes one JSONL line per record, tagged with its collection' do
      target = asset_tmp_path('tmp/memory_dump_spec.jsonl')
      target.dirname.mkpath
      target.delete if target.file?

      expect(chat).to receive(:all_collections)
        .and_return(double('DS', where: double('DS2', pluck: %w[ memory-a ])))
      expect(chat).to receive(:choose_with_state).and_yield
      expect(chat).to receive(:choose_entry).and_return('[ALL]')

      tag = double('Tag')
      allow(tag).to receive(:to_s).and_return('2026-01-01T00:00:00+02:00')
      rec = double('Record', text: 'hello',
                    tags: [ tag ],
                    source: nil)
      expect(chat).to receive(:switch_collection).with('memory-a').and_yield
      expect(docs).to receive(:each_record).and_yield(rec)

      expect(chat).to receive(:log)
      allow(chat).to receive(:feedback)

      chat.memory_dump(target.to_s)

      lines = target.read.lines
      expect(lines.size).to eq(1)
      expect(lines.first.strip).to eq(
        '{"collection":"memory-a","text":"hello","tags":["2026-01-01T00:00:00+02:00"]}'
      )
    ensure
      target&.delete if target&.file?
    end
  end

  describe '#memory_restore' do
    let :target do
      asset_tmp_path('tmp/memory_restore_spec.jsonl')
    end

    before do
      target.dirname.mkpath
      target.write(<<~JSONL)
        {"collection":"memory-a","text":"hello","tags":["2026-01-01T00:00:00+02:00"]}
        {"collection":"memory-a","text":"world","tags":["2026-01-02T00:00:00+02:00"]}
        {"collection":"memory-b","text":"foo","tags":["2026-01-03T00:00:00+02:00"]}
      JSONL
    end

    after do
      target.delete if target.file?
    end

    it 'restores each record into its collection with the original tag' do
      expect(chat).to receive(:choose_with_state).and_yield
      expect(chat).to receive(:choose_entry).and_return('[ALL]')
      expect(chat).to receive(:create_memory_collection).with('memory-a')
      expect(chat).to receive(:create_memory_collection).with('memory-b')
      expect(chat).to receive(:switch_collection).with('memory-a').and_yield
      expect(chat).to receive(:switch_collection).with('memory-b').and_yield

      expect(docs).to receive(:add)
        .with(['hello'], tags: [ '2026-01-01T00:00:00+02:00' ],
             batch_size: 1, source: nil)
      expect(docs).to receive(:add)
        .with(['world'], tags: [ '2026-01-02T00:00:00+02:00' ],
             batch_size: 1, source: nil)
      expect(docs).to receive(:add)
        .with(['foo'], tags: [ '2026-01-03T00:00:00+02:00' ],
             batch_size: 1, source: nil)

      allow(chat).to receive(:feedback)
      expect(chat).to receive(:log)
      expect(chat).to receive(:feedback)
        .with(a_string_including('Restored 3 record'), type: :success)

      chat.memory_restore(target.to_s)
    end

    it 'cancels when the user selects nothing' do
      expect(chat).to receive(:choose_with_state).and_yield
      expect(chat).to receive(:choose_entry).and_return('[DONE]')
      expect(chat).to receive(:feedback)
        .with(a_string_including('Cancelled, no collections selected'),
              type: :cancel)
      expect(chat).not_to receive(:create_memory_collection)
      chat.memory_restore(target.to_s)
    end

    it 'restores only the selected collection when picking individually' do
      expect(chat).to receive(:choose_with_state).and_yield
      expect(chat).to receive(:choose_entry)
        .and_return('memory-a', '[DONE]')
      expect(chat).to receive(:create_memory_collection).with('memory-a')
      expect(chat).not_to receive(:create_memory_collection).with('memory-b')
      expect(chat).to receive(:switch_collection).with('memory-a').and_yield
      expect(chat).not_to receive(:switch_collection).with('memory-b')

      expect(docs).to receive(:add)
        .with(['hello'], tags: [ '2026-01-01T00:00:00+02:00' ],
             batch_size: 1, source: nil)
      expect(docs).to receive(:add)
        .with(['world'], tags: [ '2026-01-02T00:00:00+02:00' ],
             batch_size: 1, source: nil)

      allow(chat).to receive(:feedback)
      expect(chat).to receive(:log)
      expect(chat).to receive(:feedback)
        .with(a_string_including('Restored 2 record'), type: :success)

      chat.memory_restore(target.to_s)
    end

    it 'warns when the file does not exist' do
      expect(chat).to receive(:feedback)
        .with(a_string_including('not found'), type: :warn)
      chat.memory_restore('tmp/no_such_memory.jsonl')
    end
  end
end
