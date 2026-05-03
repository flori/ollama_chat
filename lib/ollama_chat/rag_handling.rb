# A module that handles Retrieval-Augmented Generation (RAG) operations for the
# OllamaChat application.
#
# This module provides functionality for managing collections, clearing and
# changing collections, listing collections, and renaming collections within
# the RAG system.
module OllamaChat::RAGHandling
  private

  # Clears documents from the collection through an interactive user interface.
  #
  # This method allows users to selectively clear documents by choosing
  # specific tags from the current collection or to clear all documents in the
  # collection. It provides a loop for multiple deletions until the user exits
  # or completes a clear operation.
  def clear_collection
    loop do
      tags = @documents.tags.add('[EXIT]').add('[ALL]')
      tag = OllamaChat::Utils::Chooser.choose(tags, prompt: 'Clear? %s')
      case tag
      when nil, '[EXIT]'
        STDOUT.puts "Exiting chooser."
        break
      when '[ALL]'
        if confirm?(prompt: '🔔 Are you sure? (y/n) ', yes: /\Ay/i)
          @documents.clear
          STDOUT.puts "Cleared collection #{bold{@documents.collection}}."
          break
        else
          STDOUT.puts 'Cancelled.'
          sleep 3
        end
      when /./
        @documents.clear(tags: [ tag ])
        STDOUT.puts "Cleared tag #{tag} from collection #{bold{@documents.collection}}."
        sleep 3
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
    collections = collections.compact.map(&:to_s).uniq.sort
    collections.unshift('[EXIT]').unshift('[NEW]')
    collection = OllamaChat::Utils::Chooser.choose(collections) || current_collection
    case collection
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
    @session.update(current_collection: @documents.collection)
    STDOUT.puts "Using collection #{bold{@documents.collection}}."
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

  # Displays the list of available collections in the terminal.
  #
  # This method retrieves the current collection and the full list of available
  # collections from the internal document handler, highlighting the active one.
  def list_collections
    current_collection = @documents.collection
    STDOUT.puts @documents.collections.
      map { |c| current_collection == c ? bold { c } : c }
  end
end
