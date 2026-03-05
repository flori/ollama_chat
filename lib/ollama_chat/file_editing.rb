# Module for editing files using the configured editor
module OllamaChat::FileEditing
  # Opens a file in the configured editor for editing.
  #
  # @param filename [String, Pathname] Path to the file to edit
  # @return [true, false, nil] Exit status if successful, nil if editor not
  #   configured
  def edit_file(filename)
    unless editor = OC::EDITOR?
      STDERR.puts "Need the environment variable var EDITOR defined to use an editor"
      return
    end
    system Shellwords.join([ editor, filename ])
  end

  # The edit_text method temporarily writes the given text to a file,
  # attempts to edit it using an external editor, and returns the edited
  # content if successful.
  #
  # @param text [String] the text to be edited
  #
  # @return [String, nil] the edited text or nil if editing failed
  def edit_text(text)
    Tempfile.open do |tmp|
      tmp.write(text)
      tmp.flush

      if result = edit_file(tmp.path)
        new_text = File.read(tmp.path)
        return new_text
      else
        STDERR.puts "Editor failed to edit message."
      end
    end
  end

  # The vim method creates and returns a new Vim instance for interacting with
  # a Vim server.
  #
  # This method initializes a Vim client that can be used to insert text into
  # Vim buffers or open files in a running Vim server. It derives the server
  # name from the provided argument or uses a default server name based on the
  # current working directory.
  #
  # @param server_name [ String, nil ] the name of the Vim server to connect to
  #   If nil or empty, a default server name is derived from the current
  #   working directory
  #
  # @return [ OllamaChat::Vim ] a new Vim instance configured with the
  #   specified server name
  def vim(server_name = nil)
    clientserver = config.vim?&.clientserver
    OllamaChat::Vim.new(server_name, clientserver:)
  end

  # Inserts provided **text** into Vim using the configured editor client.
  #
  # @param [String, nil] text    – Text to insert; if `nil`, defaults to the
  #   last response.
  #
  # @param [true, false]     content  – Treat input as content‑mode (`true`) or
  #   plain text (`false`).
  #
  # @return [true, false] true if insertion succeeded; otherwise raises
  #   OllamaChat::OllamaChatError.
  #
  # @raise [OllamaChat::OllamaChatError]
  #   * Raised when no text is available and insertion cannot proceed.
  #   * Also raised if the underlying Vim client reports a failure.
  def perform_insert(text: nil, content: false)
    text ||= last_message_content(content:)
    if text
      unless vim.insert(text)
        raise OllamaChat::OllamaChatError, "Inserting text into editor failed!"
      end
      true
    else
      raise OllamaChat::OllamaChatError,
        "No text available to copy to the system clipboard."
    end
  end
end
