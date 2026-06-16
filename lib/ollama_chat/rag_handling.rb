# A module that handles Retrieval-Augmented Generation (RAG) operations for the
# OllamaChat application.
#
# This module provides functionality for managing collections, clearing and
# changing collections, listing collections, and renaming collections within
# the RAG system.
module OllamaChat::RAGHandling
  private

  # Returns the name of the currently active document collection.
  #
  # @return [String, Symbol] the name of the current collection
  def collection
    @documents.collection
  end

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
        tag = choose_entry(tags, prompt: 'Clear? %s')
        case tag
        when nil, '[EXIT]'
          STDOUT.puts "Exiting chooser."
          break
        when '[ALL]'
          if confirm?(prompt: '🔔 Are you sure? (y/n) ', yes: /\Ay/i)
            @documents.clear
            STDOUT.puts "Cleared collection #{bold{collection}}."
            break
          end
        when /./
          @documents.clear(tags: [ tag ])
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
    collections = [ current_collection ] + @documents.collections.to_a
    collections = collections.filter_map(&:to_s).uniq.sort
    collections.unshift('[EXIT]').unshift('[NEW]')
    collection = choose_entry(collections) || current_collection
    case collection&.to_s
    when '[NEW]'
      @documents.collection = ask?(
        prompt: "❓ Enter name of the new collection: "
      )
    when nil, '[EXIT]'
      STDOUT.puts "Exiting chooser."
    when /./
      @documents.collection = collection
    end
  ensure
    @session.update(current_collection: collection)
    STDOUT.puts "Using collection #{bold{collection}}."
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
    switch_history(:rename_collection) do
      prompt = 'Rename collection %s to: ' % current_collection
      if new_collection = ask?(prompt:, prefill: current_collection).full?(:to_sym)
        begin
          @documents.rename_collection(new_collection)
          STDOUT.puts "Renamed current collection #{current_collection} to #{new_collection}."
        rescue
          STDERR.puts "Renaming to #{new_collection} failed, it already exists."
        end
      else
        STDOUT.puts "Renaming cancelled."
      end
    end
  end

  # Displays the list of available collections in the terminal.
  #
  # This method retrieves the current collection and the full list of available
  # collections from the internal document handler, highlighting the active one.
  def list_collections
    current_collection = collection
    STDOUT.puts @documents.collections.
      map { |c| current_collection == c ? bold { c } : c }
  end

  # Updates the documents in the current collection by re-embedding any sources
  # that have been modified since they were first added.
  #
  # This method iterates through all records in the active collection and
  # identifies unique sources. For each modified source, it preserves the
  # existing tags, removes the stale records, and re-embeds the current
  # version of the source.
  #
  # @return [String] a newline-separated string of embedding result messages.
  def update_collection
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
    results * "\n"
  end
end
