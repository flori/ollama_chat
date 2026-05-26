# A module that provides history management functionality for OllamaChat
# sessions.
#
# The History module encapsulates methods for initializing, saving, and
# clearing command-line history within the OllamaChat application. It handles
# persistence of user input history to a file and ensures that chat sessions
# can maintain state across invocations by loading previous command histories.
module OllamaChat::History
  class << self
    # A hash storing multiple history namespaces.
    # Keys are symbols representing the namespace (e.g., :chat, :session_name),
    # and values are arrays of strings containing the command history.
    attr_accessor :histories

    # The currently active history namespace.
    # @return [Symbol] the name of the current history namespace (e.g., :chat).
    attr_accessor :current_history
  end
  self.histories       = {}
  self.current_history = :chat

  private

  # @return [Symbol] the current active history namespace
  def current_history
    OllamaChat::History.current_history
  end

  # @param value [Symbol] the new active history namespace
  def current_history=(value)
    OllamaChat::History.current_history = value
  end

  # @return [Hash{Symbol => Array<String>}] the map of all history namespaces
  def histories
    OllamaChat::History.histories
  end

  # Temporarily switches the active Reline history to the specified namespace.
  #
  # This method captures the current Reline::HISTORY, replaces it with the history
  # associated with the given name, executes the provided block, and then
  # restores the original history regardless of whether the block succeeds.
  #
  # @param name [Symbol, String] the name of the history namespace to switch to
  # @param block [Proc] the block to execute within the switched history context
  # @return [Object] the result of the block execution
  # @raise [ArgumentError] if no block is provided
  def switch_history(name, &block)
    block or raise ArgumentError, 'require &block argument'
    name = name.to_sym
    histories[name] ||= []
    if current_history == name
      return block.(name)
    end
    old_history = current_history
    histories[old_history] = Reline::HISTORY.dup
    self.current_history = name
    Reline::HISTORY.clear.push(*histories[name])
    block.(name)
  ensure
    if old_history
      histories[name] = Reline::HISTORY.dup
      Reline::HISTORY.clear.push(*histories[old_history])
      self.current_history = old_history
    end
  end

  # The init_history method initializes the chat session by loading
  # previously saved command history from a JSON or JSONL file.
  #
  # This method checks for the existence of a chat history file and, if found,
  # loads its contents into the Reline::HISTORY array. It clears the current
  # history and replaces it with the saved history data. Any errors during the
  # loading process are caught and logged as warnings, but do not interrupt the
  # execution flow.
  def init_history
    switch_history(:chat) do
      input = StringIO.new(session.history)
      history_data = OllamaChat::Utils::JSONJSONLIO.new('as.jsonl').
        read_io(input:).to_a
      Reline::HISTORY.clear
      Reline::HISTORY.push(*history_data)
    end
  end

  # The save_history method persists the current command history to a file.
  #
  # This method serializes the Reline::HISTORY array into JSON or JSONL
  # format and writes it to the chat history filename. It handles potential
  # errors during the write operation by catching exceptions and issuing a
  # warning message.
  def save_history
    switch_history(:chat) do
      output = StringIO.new
      OllamaChat::Utils::JSONJSONLIO.new('as.jsonl').
        write_io(output:, collection: Reline::HISTORY)
      session.history = output.string
    end
  end

  # The clear_history method clears the Readline history array and ensures that
  # the chat history is saved afterwards.
  #
  # This method removes all entries from the Reline::HISTORY array,
  # effectively clearing the command history maintained by the readline
  # library. It then calls save_history to persist this cleared state to the
  # configured history file. The method uses an ensure block to guarantee that
  # save_history is called even if an exception occurs during the clearing
  # process.
  def clear_history
    switch_history(:chat) do
      Reline::HISTORY.clear
    ensure
      save_history
    end
  end
end
