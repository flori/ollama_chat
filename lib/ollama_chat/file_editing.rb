# Module for editing files using the configured editor
module OllamaChat::FileEditing
  # Opens a file in the configured editor for editing.
  #
  # @param filename [String, Pathname] Path to the file to edit
  # @return [Boolean, nil] Exit status if successful, nil if editor not
  #   configured
  def edit_file(filename)
    unless editor = OC::EDITOR?
      STDERR.puts "Need the environment variable var EDITOR defined to use an editor"
      return
    end
    system Shellwords.join([ editor, filename ])
  end
end
