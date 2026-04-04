# A module that handles favourite operations for OllamaChat.
#
# This module provides functionality for managing favourites within the
# OllamaChat application, allowing users to save and retrieve favourite items
# such as models, prompts, or other configurations.
module OllamaChat::FavouritesHandling
  private

  # The prefix_favourite method adds a favorite indicator to a string.
  #
  # @param string [ String ] the string to be prefixed
  # @param enabled [ TrueClass, FalseClass ] flag to determine favorite status
  #
  # @return [ String ] the prefixed string with favorite indicator
  def prefix_favourite(string, enabled)
    fav = enabled ? '❤️' : '🩶'
    "%s %s" % [ fav, string ]
  end

  # The add_favourite method adds a favourite item of a specified type. It
  # iterates through available favourites and allows the user to select
  # from items that haven't been favourited yet.
  #
  # @param type [ String ] the context type for the favourite
  # @param all_things [ Array ] array of all available items to choose from
  #
  # @note This method uses a chooser to present options and handles user input
  #       for adding new favourites to the database.
  def add_favourite(type, all_things)
    loop do
      selected = models::Favourite.where(context: type).map(&:name)
      to_select = all_things - selected
      to_select = [ '[EXIT]' ] + to_select
      case chosen = OllamaChat::Utils::Chooser.choose(to_select)
      when '[EXIT]', nil
        STDOUT.puts "Exiting chooser."
        return
      when *to_select
        if models::Favourite.create(context: type, name: chosen.ask_and_send_or_self(:value).to_s)
          puts "Favourited %s %s" % [ type, bold { prefix_favourite(chosen.ask_and_send_or_self(:value), true) } ]
        else
          puts "Could not favourite %s %s" % [ type, bold { chosen } ]
        end
        confirm?(prompt: "\n⏎  Press any key to continue (%s). ", timeout: 3)
      end
    end
  end

  # The delete_favourite method removes a favourite item from the database.
  #
  # @param type [ String ] the context type of the favourite to delete
  # @param all_things [ Array ] the list of all available things to choose from
  def delete_favourite(type, all_things)
    to_select = models::Favourite.where(context: type).map(&:name)
    to_select = all_models.select { to_select.member?(_1.value) }
    to_select = [ '[EXIT]' ] + to_select
    case chosen = OllamaChat::Utils::Chooser.choose(to_select)
    when '[EXIT]', nil
      STDOUT.puts "Exiting chooser."
      return
    when *to_select
      if models::Favourite.where(context: type, name: chosen.ask_and_send_or_self(:value).to_s).destroy
        puts "Unfavourited %s %s" % [ type, bold { prefix_favourite(chosen.ask_and_send_or_self(:value), false) } ]
      else
        puts "Could not unfavourite %s %s" % [ type, bold { chosen } ]
      end
      confirm?(prompt: "\n⏎  Press any key to continue (%s). ", timeout: 3)
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
