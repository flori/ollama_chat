# A module that handles Retrieval-Augmented Generation (RAG) operations for the
# OllamaChat application.
#
# This module provides functionality for managing collections, clearing and
# changing collections, listing collections, and renaming collections within
# the RAG system.
module OllamaChat::RAGHandling
  # Temporarily switches the RAG collection to the specified collection.
  #
  # The current collection is stored and restored after the block is executed,
  # ensuring the state remains consistent regardless of whether the block
  # completes successfully or raises an error.
  #
  # @param other_collection [String, nil] the collection to switch to.
  #   If nil, the current collection is used.
  # @yield The code to execute within the context of the switched collection.
  # @return [Object] the result of the block.
  def switch_collection(other_collection = nil)
    other_collection ||= collection
    old_collection, @documents.collection = collection, other_collection
    yield other_collection
  ensure
    @documents.collection = old_collection
  end

  private

  # Looks up a collection in the database by name.
  #
  # @param collection [String, Symbol, #to_s] the collection name to look up
  # @return [OllamaChat::Database::Models::Collection, nil] the found
  #   collection, or `nil` if not present in the database
  def database_collection?(collection)
    models::Collection[name: collection.to_s]
  end

  # Returns the name of the currently active document collection.
  #
  # @return [String, Symbol] the name of the current collection
  def collection
    @documents.collection
  end

  # Clears documents from the collection through an interactive user interface.
  #
  # This method allows users to selectively clear documents by choosing
  # specific tags from the current collection or to clear all documents in the
  # collection. It provides a loop for multiple deletions until the user exits
  # or completes a clear operation.
  def clear_collection
    choose_with_state do
      loop do
        tags = @documents.tags.to_a.unshift('[ALL]').unshift('[EXIT]')
        tag = choose_entry(
          tags,
          prompt: 'What obsolete records are to be excised from the annals? %s'
        )
        case tag
        when nil, '[EXIT]'
          STDOUT.puts "Exiting chooser."
          break
        when '[ALL]'
          if confirm?(prompt: '🔔 Are you sure? (y/n) ', yes: /\Ay/i)
            @documents.clear
            log(:info, "Collection cleared", data: { collection: })
            STDOUT.puts "Cleared collection #{bold{collection}}."
            break
          end
        when /./
          @documents.clear(tags: [ tag ])
          log(:info, "Tag cleared from collection", data: { collection:, tag: })
          STDOUT.puts "Cleared tag #{tag} from collection #{bold{collection}}."
        end
      end
    end
  end

  # Sets the current document collection.
  #
  # @param collection [String, Symbol] the name of the collection to set
  # @return [String, Symbol] the newly set collection name
  def set_current_collection(collection)
    @documents.collection = collection
  end

  # The choose_collection method presents a menu to select or create a document
  # collection. It displays existing collections along with options to create a
  # new one or exit.
  # The method prompts the user for input and updates the document collection
  # accordingly.
  #
  # @param current_collection [ String, nil ] the name of the currently active collection
  def choose_collection(current_collection)
    collections = [ current_collection ] + all_collections.pluck(:name)
    collections = collections.filter_map(&:to_s).uniq.sort
    collections.unshift('[EXIT]').unshift('[NEW]')
    collection = choose_entry(
      collections,
      prompt: 'Which archive of knowledge shall we delve into? %s'
    ) || current_collection
    case collection = collection&.to_s
    when '[NEW]'
      if name = create_collection
        @documents.collection = name
      end
    when nil, '[EXIT]'
      STDOUT.puts "Exiting chooser."
    when /./
      @documents.collection = collection
    end
  ensure
    if collection
      @session.update(current_collection: collection)
      log(:info, "Collection switched", data: { collection: })
      STDOUT.puts "Using collection #{bold{collection}}."
    end
    info
  end

  # Rename an existing collection to a new, user‑supplied name.
  #
  # This helper prompts the user to provide a new name for the collection
  # identified by <code>current_collection</code>. It then renames the current
  # collection to have the new_name and switches to it.
  #
  # @param current_collection [Symbol] the current collection name
  def rename_collection(current_collection)
    prompt = 'Rename collection %s to: ' % current_collection
    new_collection = switch_history :collection_name do
      ask?(prompt:, prefill: current_collection).full?(:to_sym)
    end
    if new_collection
      begin
        @documents.rename_collection(new_collection)
        col = database_collection?(current_collection)
        col&.update(name: new_collection.to_s)
        log(:info, "Collection renamed", data: { old_name: current_collection, new_name: new_collection })
        STDOUT.puts "Renamed current collection #{current_collection} to #{new_collection}."
      rescue Sequel::UniqueConstraintViolation
        STDERR.puts "❌ Renaming to #{new_collection} failed, it already exists in database."
      rescue => e
        STDERR.puts "❌ Renaming to #{new_collection} failed: #{e.message}"
      end
    else
      STDOUT.puts "Renaming cancelled."
    end
  end

  # Retrieves all document collections registered in the database.
  #
  # @return [Sequel::Dataset] a dataset of all collections ordered by name.
  def all_collections
    models::Collection.order(:name)
  end

  # Displays the list of available collections in the terminal.
  #
  # This method retrieves the current collection and the full list of available
  # collections and their descriptions from the internal document handler,
  # highlighting the active one.
  def list_collections
    current_collection = collection.to_s
    collections = all_collections.select(:name, :description)
    use_pager do |output|
      collections.each { |c|
        collection_name = current_collection == c.name ? bold { c.name } : c.name
        collection_description = c.description
        output.puts '%s: %s' % [ collection_name, collection_description ]
      }
    end
  end

  # Updates the documents in the current collection by re-embedding any sources
  # that have been modified since they were first added, and embedding any new
  # files matching the collection's patterns.
  #
  # This method iterates through all records in the active collection and
  # identifies unique sources. For each modified source, it preserves the
  # existing tags, removes the stale records, and re-embeds the current
  # version of the source. It then scans for new files matching the
  # collection's patterns and embeds them.
  #
  # @return [String] a newline-separated string of embedding result messages.
  def update_collection(collection)
    switch_collection(collection) do
      unless col = database_collection?(collection)
        STDERR.puts "❌ Collection #{collection.inspect} not found in database."
        return
      end
      results = []
      seen = {}
      @documents.each_record do |record|
        source = @documents.normalize_source(record.source) or next
        seen.key?(source) and next
        seen[source] = true
        unless @documents.source_modified?(source)
          infobar.puts "Source #{source.to_s.inspect} is unmodified. => Skipping."
          next
        end
        tags = record.tags_set
        @documents.source_remove(source)
        r = embed(source, tags:) or next
        results << r
      end

      if patterns = col.patterns.full?
        all_file_set(patterns).each do |file|
          seen[file.to_s] and next
          seen[file.to_s] = true
          r = embed(file.to_s, tags: []) or next
          results << r
        end
      end

      log(:info, "Collection updated", data: { collection:, sources_updated: results.size })
      results * "\n"
    end
  end

  # Extracts and normalizes file patterns from a shell-style string.
  #
  # Splits the input string using shell semantics, correctly handling
  # spaces enclosed in single/double quotes or escaped with backslashes.
  # Each resulting pattern is expanded to an absolute path.
  #
  # @param patterns_str [String, nil] the shell-style glob patterns
  # @return [Array<String>] an array of expanded absolute path patterns
  def extract_patterns(patterns_str)
    patterns = Shellwords.split(patterns_str.to_s)
    patterns.map { File.expand_path(_1) }
  end

  # Interactively create a new collection record.
  def create_collection
    name = switch_history(:collection_name) do
      ask?(prompt: "📚 Name of the new collection: ")
    end
    unless name.full?
      STDERR.puts "❌ Cancelled creation of collection."
      return
    end

    if database_collection?(name)
      STDERR.puts "❌ Collection #{name.inspect} already exists."
      return
    end

    description = switch_history(:collection_description) do
      ask?(prompt: "📝 Description: ")
    end
    unless description.full?
      STDERR.puts "❌ Cancelled creation of collection #{name.inspect}."
      return
    end
    patterns_str = switch_history(:patterns) do
      ask?(prompt: "🔍 Patterns (space-separated globs, e.g., lib/**/*.rb): ")
    end
    patterns = extract_patterns(patterns_str)

    begin
      models::Collection.create(
        name: name.to_s,
        description: description.to_s,
        patterns:
      )
      if patterns.full?
        update_collection(name.to_s)
      end
      STDOUT.puts "✅ Created collection '#{name}'."
      log(:info, "Collection created", data: { name:, description:, patterns: })
    rescue Sequel::UniqueConstraintViolation
      STDERR.puts "❌ Collection #{name.inspect} already exists."
    rescue Sequel::Error => e
      STDERR.puts "❌ Database error: #{e.message}"
    end
    name.to_s
  end

  # Interactively update attributes of an existing collection.
  def edit_collection
    collections = models::Collection.order(:name).pluck(:name)
    collections.unshift('[CANCEL]')
    target_name = choose_entry(
      collections,
      prompt: '📚 Which collection to edit? %s'
    )
    return if target_name.nil? || target_name == '[CANCEL]'

    col = database_collection?(target_name)
    unless col
      STDERR.puts "❌ Collection #{target_name.inspect} not found in database."
      return
    end

    new_description = switch_history :collection_description do
      ask?(
        prompt: "📝 New description (leave blank to keep): ",
        prefill: col.description
      )
    end
    patterns = switch_history :patterns do
      patterns_str = ask?(
        prompt: "🔍 New patterns (space-separated, leave blank to keep): ",
        prefill: col.patterns.full?(:join, ' ')
      )
      extract_patterns(patterns_str)
    end

    col.description = new_description.full? ? new_description.to_s : col.description
    col.patterns    = patterns

    begin
      col.save
      STDOUT.puts "✅ Updated collection '#{col.name}'."
      log(:info, "Collection updated", data: { name: col.name })
    rescue Sequel::Error => e
      STDERR.puts "❌ Database error: #{e.message}"
    end
  end

  # Permanently remove a collection from DB and purge from Documentrix.
  def delete_collection
    choose_with_state do
      loop do
        collections = models::Collection.order(:name).pluck(:name)
        collections.unshift('[CANCEL]')
        target_name = choose_entry(
          collections,
          prompt: '🗑️ Which collection to delete? %s'
        )
        break if target_name.nil? || target_name == '[CANCEL]'

        col = database_collection?(target_name)
        unless col
          STDERR.puts "❌ Collection #{target_name.inspect} not found in database."
          next
        end

        if confirm?(prompt: "⚠️ Are you sure you want to permanently delete #{target_name.inspect}? (y/n) ", yes: /\Ay/i)
          begin
            col.chat = self
            col.destroy
            STDOUT.puts "✅ Deleted collection #{target_name.inspect}."
            log(:info, "Collection deleted", data: { name: target_name })
          rescue Sequel::Error => e
            STDERR.puts "❌ Database error: #{e.message}"
          rescue => e
            STDERR.puts "❌ Error removing from Documentrix: #{e.message}"
          end
        else
          STDOUT.puts "🚫 Deletion cancelled."
        end
      end
    end
  end
end
