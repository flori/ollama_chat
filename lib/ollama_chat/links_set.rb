# A collection of links associated with a chat session, providing automatic
# synchronization to the session's persistent storage.
#
# This class acts as a wrapper around a Set, ensuring that any mutations
# trigger a sync operation to save the current state to the database.
#
# @see OllamaChat::SessionManagement
class OllamaChat::LinksSet
  # Initializes a new LinksSet instance and loads existing links from the
  # session.
  #
  # @param chat [Object] The chat instance used for persistence.
  def initialize(chat)
    @chat = chat
    @set  = Set.new(@chat.load_links_from_session)
  end

  # Adds a link to the set and synchronizes it with the session.
  #
  # @param x [String] The link to add.
  # @return [OllamaChat::LinksSet] returns self.
  def add(x)
    @set.add(x)
    sync
  end

  # Removes all links from the set and synchronizes it with the session.
  #
  # @return [OllamaChat::LinksSet] returns self.
  def clear
    @set.clear
    sync
  end

  # Removes a specific link from the set and synchronizes it with the session.
  #
  # @param x [String] The link to delete.
  # @return [String, nil] The deleted link, or nil if it was not found.
  def delete(x)
    @set.delete(x).tap { sync }
  end

  # Synchronizes the current in-memory set of links with the chat session.
  #
  # @return [OllamaChat::LinksSet] returns self.
  def sync
    @chat.store_links_in_session(@set)
    self
  end

  # Checks if the set of elements is empty.
  #
  # @return [Boolean] true if the set contains no elements, false otherwise.
  def empty?
    @set.empty?
  end

  # Returns the number of elements in the set.
  # @return [Integer] the size of the set
  def size
    @set.size
  end

  # Iterates over the links in the set.
  #
  # @yield [String] The current link in the iteration.
  # @return [OllamaChat::LinksSet] returns self.
  def each(&block)
    @set.each(&block)
    self
  end

  include Enumerable
end
