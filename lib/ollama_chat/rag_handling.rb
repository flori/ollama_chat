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

  # Looks up a collection in the database by name.
  #
  # @param collection [String, Symbol, #to_s] the collection name to look up
  # @return [OllamaChat::Database::Models::Collection, nil] the found
  #   collection, or `nil` if not present in the database
  def database_collection?(collection)
    models::Collection[name: collection.to_s]
  end

  # Creates (or reuses) the persistent memory collection for a persona.
  #
  # The collection is named "memory-#{persona_name}" and is registered in
  # the local database with an empty pattern list. If a collection with
  # that name already exists, it is returned as-is without modification.
  #
  # This is the single canonical entry point for ensuring a persona's
  # memory collection exists before it is referenced by the trigger
  # mechanism, the `memorize`/`forget` tools, or any other consumer.
  #
  # @param persona_name [String] the persona stem (e.g. "miyu_pairing")
  #   whose memory collection should be available.
  # @return [String] the collection name (e.g. "memory-miyu_pairing").
  def create_memory_collection(persona_name)
    collection = "memory-#{persona_name}"

    unless chat.database_collection?(collection)
      models::Collection.create(
        name:        collection,
        description: "Memory for persona #{persona_name}",
        patterns:    [],
      )
    end

    collection
  end

  private

  # Returns the name of the currently active document collection.
  #
  # @return [String, Symbol] the name of the current collection
  def collection
    @documents.collection
  end

  # The clear_whole_collection method confirms user intent to delete the entire
  # collection, then clears all documents and logs the action, returning self
  # on success.
  #
  # @return [ nil, OllamaChat::Chat ] when the user declines the confirmation
  #   prompt, self otherwise.
  def clear_whole_collection
    if confirm?(prompt: '🔔 Really delete the whole collection? Are you sure? (y/n) ', yes: /\Ay/i)
      @documents.clear
      log(:info, "Collection cleared", data: { collection: })
      feedback("Cleared collection #{bold{collection}}.", type: :info)
      self
    else
      feedback('Denied.', type: :denied)
      nil
    end
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
          feedback("Exiting chooser.")
          break
        when '[ALL]'
          clear_whole_collection and break
        when /./
          @documents.clear(tags: [ tag ])
          log(:info, "Tag cleared from collection", data: { collection:, tag: })
          feedback("Cleared tag #{tag} from collection #{bold{collection}}.", type: :info)
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
      feedback("Exiting chooser.")
    when /./
      @documents.collection = collection
    end
  ensure
    if collection
      @session.update(current_collection: collection)
      log(:info, "Collection switched", data: { collection: })
      feedback("Using collection #{bold{collection}}.", type: :info)
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
        feedback("Renamed current collection #{current_collection} to #{new_collection}.", type: :info)
        refresh_system_prompt
      rescue Sequel::UniqueConstraintViolation
        feedback("Renaming to #{new_collection} failed, it already exists in database.", type: :warn)
      rescue => e
        feedback("Renaming to #{new_collection} failed: #{e.message}", type: :warn)
      end
    else
      feedback("Renaming cancelled.", type: :cancel)
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
    collections = all_collections.select(:name, :description, :enabled)
    use_pager do |output|
      collections.each { |c|
        enabled                = c.enabled ? '✅' : '⛔'
        collection_name        = current_collection == c.name ? bold { c.name } : c.name
        collection_description = c.description

        output.puts '%s %s: %s' % [ enabled, collection_name, collection_description ]
      }
    end
  end

  # Queries the active collection for matching records and prints
  # a scored result table for debugging and inspection.
  #
  # @param edit [Boolean] use `edit_text` for query input (default: false)
  # @param rerank [Boolean] apply LLM rerank to results (default: false)
  def query_collection(edit: false, rerank: false)
    unless embedding.on?
      feedback("Embedding is disabled.", type: :warn)
      return
    end
    query =
      if edit
        edit_text.full?(:strip)
      else
        switch_history(:query) { ask?(prompt: "🔍 Query: ").full?(:strip) }
      end
    query.blank? and return

    records = find_document_records(query)
    if rerank && records.any?
      records = rerank_records(query, records)
    end

    use_pager do |output|
      suffix = records.size == 1 ? '' : 's'
      output.puts "📚 Collection: #{collection.to_s} (#{records.size} record#{suffix})"
      output.puts
      if records.empty?
        output.puts '  No records found.'
      else
        max_num_width = Math.log10(1 + records.size).ceil
        records.each_with_index do |record, i|
          score = format('%.1f%%', record.similarity * 100)
          text  = wrap(
            truncate(record.text.strip, length: 5 * Tins::Terminal.rows),
            percentage: 90
          )
          link = if record.source =~ %r(\Ahttps?://)
                   record.source
                 elsif record.source.present?
                   'file://%s' % File.expand_path(record.source)
                 end
          tag = ?# + record.tags.first
          if tag && link
            tag = hyperlink(link, tag)
          end
          num = bold { "%#{max_num_width}u." % (i + 1) }
          feedback(format("%s %s %s", num, score, tag), output:)
          feedback(kramdown_ansi_parse("```\n%s\n```" % text), output:)
          feedback(kramdown_ansi_parse(?- * 3), output:)
        end
      end
    end
    log(:info, "Collection queried", data: {
      collection: collection.to_s, query:, hits: records.size, rerank:
    })
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
    results = []
    switch_collection(collection) do
      unless col = database_collection?(collection)
        feedback("Collection #{collection.inspect} not found in database.", type: :warn)
        return ''
      end
      sources = {}
      seen = {}
      @documents.each_record do |record|
        source = @documents.normalize_source(record.source) or next
        seen.key?(source) and next
        seen[source] = true
        unless @documents.source_modified?(source)
          infobar.puts "Source #{source.to_s.inspect} is unmodified. => Skipping."
          next
        end
        sources[source] = record.tags_set
        @documents.source_remove(source)
      end

      if patterns = col.patterns.full?
        new_sources = all_file_set(patterns).map(&:to_s).reject { seen.key?(_1) }
        new_sources.each { seen[_1] = true }
        new_sources.each { sources[_1] = [] }
      end

      results.concat(bulk_embed_sources(sources))
      log(:info, "Collection updated", data: { collection:, sources_updated: results.size })
    end
    results * ?\n
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
      feedback("Cancelled creation of collection.", type: :cancel)
      return
    end

    if database_collection?(name)
      feedback("Collection #{name.inspect} already exists.", type: :warn)
      return
    end

    description = switch_history(:collection_description) do
      ask?(prompt: "📝 Description: ")
    end
    unless description.full?
      feedback("Cancelled creation of collection #{name.inspect}.", type: :cancel)
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
      feedback("Created collection '#{name}'.", type: :success)
      log(:info, "Collection created", data: { name:, description:, patterns: })
      refresh_system_prompt
    rescue Sequel::UniqueConstraintViolation
      feedback("Collection #{name.inspect} already exists.", type: :warn)
    rescue Sequel::Error => e
      feedback("Database error: #{e.message}", type: :warn)
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
      feedback("Collection #{target_name.inspect} not found in database.", type: :warn)
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

    enabled_prompt = col.enabled ?
      "🚫 Disable this collection? (hidden from the model) (y/n) " :
      "✅ Enable this collection? (visible to the model) (y/n) "
    toggle = case confirm?(prompt: enabled_prompt)
             when /\Ay/i then true
             when /\An/i then false
             end

    col.description = new_description.full? ? new_description.to_s : col.description
    col.patterns    = patterns
    col.enabled     = toggle ^ col.enabled unless toggle.nil?

    begin
      col.save
      if toggle
        status = col.enabled ? 'enabled' : 'disabled'
        feedback("Collection '#{col.name}' is now #{status}.", type: :info)
      end
      feedback("Updated collection '#{col.name}'.", type: :success)
      log(:info, "Collection updated", data: { name: col.name, enabled: col.enabled })
      refresh_system_prompt
    rescue Sequel::Error => e
      feedback("Database error: #{e.message}", type: :warn)
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
          feedback("Collection #{target_name.inspect} not found in database.", type: :warn)
          next
        end

        if confirm?(prompt: "⚠️ Are you sure you want to permanently delete #{target_name.inspect}? (y/n) ", yes: /\Ay/i)
          begin
            col.chat = self
            col.destroy
            feedback("Deleted collection #{target_name.inspect}.", type: :success)
            log(:info, "Collection deleted", data: { name: target_name })
            refresh_system_prompt
          rescue Sequel::Error => e
            feedback("Database error: #{e.message}", type: :warn)
          rescue => e
            feedback("Error removing from Documentrix: #{e.message}", type: :warn)
          end
        else
          feedback("Deletion denied.", type: :denied)
        end
      end
    end
  end
end
