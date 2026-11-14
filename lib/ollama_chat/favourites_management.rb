# A module that handles favourite operations for OllamaChat.
#
# This module allows users to mark specific entities as favourites and retrieve
# those favourites for easy access and display in the UI.
module OllamaChat::FavouritesManagement
  private

  # Prepend a heart icon to a string if it is marked as a favourite.
  #
  # @param string [String] the string to decorate
  # @param favourited [Boolean] whether the item is a favourite
  # @return [String] the decorated string
  def prefix_favourite(string, favourited)
    fav = favourited ? '⭐' : '⚫'
    "%s %s" % [ fav, string ]
  end

  # Retrieves a UI-ready list of all available entities of a given type,
  # decorated with a heart icon if they are marked as favourites.
  #
  # @param type [String] the context type (e.g., 'model', 'prompt', 'system', 'persona')
  # @return [Array<SearchUI::Wrapper>] a list of wrappers containing the original
  #   value and the decorated display string.
  def favourite_all_things(type)
    case type
    when 'model'         then all_models
    when 'persona'       then available_personae_names
    else                      all_prompts(context: type)
    end.to_a
  end

  # The choose_favourite method opens an interactive multi-select picker
  # showing all available items of the given type with their current
  # favourite state (⭐ / ⚫). The user toggles items with Tab and
  # applies changes with Enter.
  #
  # @param type [ String ] the context type for the favourite
  #
  # @note This method uses a multi-select chooser to present options and
  #       handles user input for adding/removing favourites in one pass.
  def choose_favourite(type)
    all_things = favourite_all_things(type).map(&:value)
    current    = all_favourited(type)
    picked     = all_things.select { current.include?(_1) }

    result = choose_multi(
      all_things,
      prompt:        "Choose favourites (#{type}): %s "\
                     "[Tab=toggle, Enter=apply, C-c=abort]",
      picked:        picked,
      picked_icon:   '⭐',
      unpicked_icon: '⚫'
    ) or return feedback('Aborted.', type: :cancel)

    to_add    = result - current.keys
    to_remove = current.keys - result

    to_add.each do |name|
      models::Favourite.create(context: type, name:)
      log(:info, 'Favourite added', data: { context: type, name: })
    end
    to_remove.each do |name|
      models::Favourite.where(context: type, name:).destroy
      log(:info, 'Favourite removed', data: { context: type, name: })
    end

    unless (to_add + to_remove).empty?
      feedback(
        "Added: %s | Removed: %s" % [ to_add.joined, to_remove.joined ]
      )
    end
  end

  # The all_favourited method retrieves all favourited items of a specified
  # type.
  #
  # @param type [ String ] the type of favourited items to retrieve
  # @return [ Hash ] a hash with favourited item names as keys and true as
  #   values
  def all_favourited(type)
    models::Favourite.where(context: type).
      each_with_object(Hash.new(false)) { |fav, h| h[fav.name] = true }
  end
end
