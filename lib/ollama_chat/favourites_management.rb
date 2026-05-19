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
    fav = favourited ? '❤️' : '🩶'
    "%s %s" % [ fav, string ]
  end

  # Retrieves a UI-ready list of all available entities of a given type,
  # decorated with a heart icon if they are marked as favourites.
  #
  # @param type [String] the context type (e.g., 'model', 'prompt', 'system_prompt', 'persona')
  # @return [Array<SearchUI::Wrapper>] a list of wrappers containing the original
  #   value and the decorated display string.
  def favourite_all_things(type)
    case type
    when 'model'         then all_models
    when 'prompt'        then all_prompts
    when 'system_prompt' then all_system_prompts
    when 'persona'       then available_personae_names
    else
      raise ArgumentError, "not all things defined for type #{type.inspect}"
    end.to_a
  end

  # The add_favourite method adds a favourite item of a specified type. It
  # iterates through available favourites and allows the user to select
  # from items that haven't been favourited yet.
  #
  # @param type [ String ] the context type for the favourite
  #
  # @note This method uses a chooser to present options and handles user input
  #       for adding new favourites to the database.
  def add_favourite(type)
    all_things = favourite_all_things(type)
    choose_with_state do
      loop do
        selected = models::Favourite.where(context: type).map(&:name)
        to_select = all_things - selected
        if to_select.empty?
          STDOUT.puts "All items are already favourited."
          return
        end
        to_select.unshift('[EXIT]')
        case chosen = choose_entry(to_select)
        when '[EXIT]', nil
          STDOUT.puts "Cancelled."
          return
        when SearchUI::Wrapper
          models::Favourite.create(context: type, name: chosen.value)
        end
      end
    end
  end

  # The delete_favourite method removes favourite items from the database.
  # It iterates through current favourites and allows the user to select
  # items for removal in a loop, maintaining search state between selections.
  #
  # @param type [ String ] the context type of the favourite to delete
  #
  # @note This method uses a chooser to present options and handles user input
  #       for removing favourites from the database.
  def delete_favourite(type)
    all_things = favourite_all_things(type)
    choose_with_state do
      loop do
        to_select = models::Favourite.where(context: type).map(&:name)
        to_select = all_things.select { to_select.member?(_1.value) }
        to_select = [ '[EXIT]' ] + to_select
        case chosen = choose_entry(to_select)
        when '[EXIT]', nil
          STDOUT.puts "Cancelled."
          return
        when SearchUI::Wrapper
          models::Favourite.where(context: type, name: chosen.value).destroy
        end
      end
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
