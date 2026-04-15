# The OllamaChat::SessionHandling module provides methods for managing chat
# sessions, including creating, listing, switching, renaming, and deleting
# sessions.
#
# It integrates closely with the database-backed Session model and ensures that
# session data is persisted correctly, especially the conversation history.
#
# @see OllamaChat::Database::Models::Session
module OllamaChat::SessionHandling
  # Persists the current conversation messages to the database.
  #
  # This method serializes the current message list into JSONL format and
  # updates the `messages` attribute of the current session.
  def store_messages_in_session
    output = StringIO.new
    messages.write_conversation_jsonl(output)
    session.update(messages: output.string)
  end

  # The session reader returns the current session object.
  #
  # @return [OllamaChat::Database::Models::Session] the current session
  #   instance
  attr_reader :session

  private

  # Creates a new, default session instance.
  #
  # @return [OllamaChat::Database::Models::Session] a new session with default
  #   attributes
  def new_session
    OllamaChat::Database::Models::Session.with_defaults(self)
  end

  # Retrieves the last used session from the database, or creates a new one if
  # none exist.
  #
  # @return [OllamaChat::Database::Models::Session] the last used or newly
  #   created session
  def last_used_session
    models::Session.order(:updated_at).last || new_session
  end

  # Lists all sessions in a formatted table.
  #
  # @param output [IO] the output stream to write the table to (default: STDOUT)
  #
  def list_sessions(output: STDOUT)
    table = Terminal::Table.new
    table.style = {
      all_separators: true,
      border:         :unicode_round,
    }
    table.headings = %w[ ID NAME SIZE COUNT ].map { |header| bold { header } }
    models::Session.order(Sequel.desc(:updated_at)).each do |s|
      size = format_bytes(s.messages.to_s.size)
      table << [
         s.id.to_s,
        session.id == s.id ? bold { s.name } : s.name,
        size,
        s.messages.to_s.count(?\n)
      ]
    end
    table.align_column 2, :right
    table.align_column 3, :right
    output.puts table
  end

  # Displays information about the current session.
  #
  # @param output [IO] the output stream to write the information to (default: STDOUT)
  def show_session(output: STDOUT)
    messages_size  = format_bytes(session.messages.to_s.size)
    messages_count = session.messages.to_s.count(?\n)
    output.puts "#{bold{session.name}} (#{italic{session.id}}), #{messages_size}, #{messages_count} messages"
  end

  # Creates a new session with the given name or a default name.
  #
  # @param name [String, nil] the name for the new session
  # @return [String, nil] the content of the new session or nil
  def set_new_session(name = nil)
    @session = new_session
    if name.full?
      session.update(name:)
    else
      session.touch
    end
    messages.clear
    if persona = session.default_persona_id.full?
      disable_content_parsing
      personae_result(persona)
    end
  end

  # Sets up the current session based on command-line options or the last used
  # session.
  #
  # @return [OllamaChat::Database::Models::Session] the initialized session
  def setup_session
    @session = if session_name = @opts[?l]
                 choose_session(session_name)
               else
                 last_used_session
               end
    session or abort "No session named #{bold{session_name.inspect}} found."
    if session.touch
      session
    else
      raise OllamaChat::OllamaChatError,
        "Could not save session #{session.errors.inspect}"
    end
  end

  # Deletes a session by name.
  #
  # @param name [String] the name of the session to delete
  def delete_session(name)
    name.full? or name = ??
    if chosen_session = choose_session(name)
      if session == chosen_session
        STDERR.puts "Cannot delete current session #{session.name.inspect}!"
      elsif confirm?(prompt: "🔔 Do you really want to delete #{chosen_session.name.inspect}? (y/n) ", yes: /\Ay/i)
        chosen_session.destroy
        STDOUT.puts "Just deleted session #{chosen_session.name.inspect}!"
      end
    end
  end

  # Renames the current session.
  def rename_session
    name = ask?(
      prompt: "❓ Enter the new name for the session (CR auto, C-c cancel): "
    )
    if name.nil?
      STDERR.puts "\nInterrupt: Session renaming was cancelled."
      return
    end
    name.empty? and name = derive_session_name
    if name && session.update(name:)
      STDOUT.puts "Renamed current session to #{name.inspect}."
    else
      STDERR.puts "Could not rename current session!"
    end
  rescue Sequel::UniqueConstraintViolation
    STDERR.puts "Could not rename current session to #{name.inspect}, already exists!"
  end

  # Generates a summary of the current session's conversation.
  #
  # @param pretty [Boolean] whether to format the summary in markdown (default: false)
  # @param sentence [Boolean] whether to summarize each message in one sentence (default: false)
  # @return [String, nil] the session summary or nil if empty
  def summarize_session(pretty: false, sentence: false)
    unit     = sentence ? 'sentence' : 'paragraph'
    contents = []
    total = messages.each_message.count
    messages.each_message.with_infobar(label: 'Summarizing message', total:) do |message|
      summary = generate(
        prompt: 'Summarize this %s message in one %s: %s' % [
          message.role, unit, message.content
        ]
      ).response
      if pretty
        contents << '**%s**: %s' % [ message.role, summary ]
      else
        contents << '%s: %s' % [ message.role, summary ]
      end
      +infobar
    end
    contents.empty? and return

    if pretty
      contents.unshift(%{# Summary of session "#{session.name}"})
      contents * "\n\n"
    else
      contents * ?\n
    end
  end

  # Derives a title for the session based on its content.
  #
  # @param length [Integer] the maximum length of the title (default: 128)
  # @return [String, nil] the derived session name or nil
  def derive_session_name(length: 128)
    content = summarize_session(sentence: true) or return
    prompt  = 'Create a title with a length of **less than %u** characters for this conversation. Output only the title and nothing else:\n\n%s'
    generate(prompt: prompt % [ length, content ]).response.full? do |name|
      name = name.
        gsub(/(\A(\s|[^A-Za-z])+|(\s|[^A-Za-z])+\z)/m, '').
        gsub(/\s+/, ' ')
      Kramdown::ANSI::Width.truncate(name, length:)
    end
  end

  # Switches to a different session, saving the current one and loading the new
  # one.
  #
  # @param name [String] the name or ID of the session to switch to
  def switch_session(name)
    name.full? or name = ??
    if chosen_session = choose_session(name)
      store_messages_in_session
      @session = chosen_session
      messages.read_conversation_jsonl(session.messages.to_s)
      session.current_model.full? { use_model(_1) }
      session.default_persona_id.full? { set_default_persona_name(_1) }
      session.touch
      info_session
    end
  end

  # Chooses a session from the database based on a name or ID.
  #
  # @param session_name [String] the name or ID of the session to choose
  # @return [OllamaChat::Database::Models::Session, nil] the chosen session or nil
  def choose_session(session_name)
    if session_name =~ /\A\d+/ and
        session = models::Session.first(id: session_name)
    then
      return session
    end
    selector = if session_name =~ /\A\?+(.*)\z/
                 session_name = ''
                 Regexp.new($1)
               end
    if session_name and session = models::Session.first(name: session_name)
      session
    elsif selector
      sessions = models::Session.order(Sequel.desc(:updated_at)).map {
        SearchUI::Wrapper.new(
          _1.name,
          display: "#{_1.name} (#{_1.id}) #{_1.messages.to_s.count(?\n)} messages #{_1.created_at.iso8601}"
        )
      }
      selector and sessions = sessions.select { _1 =~ selector }
      session_name = if sessions.size == 1
                       sessions.first.value
                     else
                       OllamaChat::Utils::Chooser.choose(sessions)&.value
                     end
      if session_name
        models::Session.first(name: session_name)
      end
    end
  end
end
