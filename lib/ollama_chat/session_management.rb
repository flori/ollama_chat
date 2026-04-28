# The OllamaChat::SessionHandling module provides methods for managing chat
# sessions, including creating, listing, switching, renaming, and deleting
# sessions.
#
# It integrates closely with the database-backed Session model and ensures that
# session data is persisted correctly, especially the conversation history.
module OllamaChat::SessionManagement
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

  # Retrieves the preferred session from the database, or creates a new one if
  # none exist.
  #
  # @return [OllamaChat::Database::Models::Session] the last used or newly
  #   created session
  def preferred_session
    models::Session.
      where(working_directory: Dir.pwd).
      order(:updated_at).last ||
      new_session
  end

  # Lists all sessions in a formatted table.
  def list_sessions
    use_pager do |output|
      table = Terminal::Table.new
      table.style = {
        all_separators: true,
        border:         :unicode_round,
      }
      table.headings = %w[ ID NAME SIZE #TOK COUNT UPDATED ].map { |header| bold { header } }
      now = Time.now
      models::Session.order(Sequel.desc(:updated_at)).each do |s|
        size_bytes  = s.messages.to_s.size
        size        = format_bytes(size_bytes)
        tokens      = OllamaChat::Utils::TokenEstimator.estimate(size_bytes)
        tokens_size = format_tokens(tokens)
        table << [
          s.id.to_s,
          session.id == s.id ? bold { s.name } : s.name,
          size,
          tokens_size,
          s.messages.to_s.count(?\n),
          s.age(now:),
        ]
      end
      table.align_column 2, :right
      table.align_column 3, :right
      table.align_column 4, :right
      table.align_column 5, :right
      output.puts table
    end
  end

  # Displays information about the current session.
  #
  # @param output [IO] the output stream to write the information to (default: STDOUT)
  def show_session(output: STDOUT)
    size_bytes = session.messages.to_s.size
    messages_size  = format_bytes(size_bytes)
    tokens         = OllamaChat::Utils::TokenEstimator.estimate(size_bytes)
    tokens_size    = format_tokens(tokens)
    messages_count = session.messages.to_s.count(?\n)
    output.puts "#{bold{session.name}} (#{italic{session.id}}), #{messages_size}/#{tokens_size}, #{messages_count} messages"
  end

  # Creates a new session with the given name or a default name.
  #
  # @param name [String, nil] the name for the new session
  def set_new_session(name = nil)
    @session = new_session
    session.lock? or raise OllamaChat::OllamaChatError,
      "Could not lock session #{session.id} #{session.errors.full?(:inspect)}"
    if name.full?
      session.update(name:)
    else
      session.touch
    end
    messages.clear
    session.current_model.full? {
      use_model(_1)
      copy_model_options_to_session
    }
    nil
  end

  # Sets up the current session based on command-line options or the last used
  # session.
  #
  # @return [OllamaChat::Database::Models::Session] the initialized session
  def setup_session
    @session = if session_name = @opts[?l]
                 choose_session(session_name)
               elsif @opts[?n]
                 new_session
               else
                 preferred_session
               end
    session or abort "No session named #{bold{session_name.inspect}} found."
    if session.lock?
      session
    else
      raise OllamaChat::OllamaChatError,
        "Could not lock session #{session.id} #{session.errors.full?(:inspect)}"
    end
  end

  # Deletes the current session and prompts the user to pick a new one to
  # switch to.
  def delete_session
    current_session_name, current_session_id = session.name, session.id
    STDOUT.puts <<~EOT
      The current session
        #{current_session_name.inspect} (#{current_session_id})
      will be deleted, pick a new session to switch to.
    EOT
    confirm?(prompt: "\n⏎  Press any key to continue (%s). ", timeout: 3)
    if chosen_session = choose_session(??, except_id: current_session_id)
      confirm?(
        prompt: "🔔 Delete session #{current_session_name.inspect} (#{current_session_id})? (y/n) ",
        yes: /\Ay/i
      ) or return
      change_session(chosen_session.id)
      models::Session.where(id: current_session_id).destroy
      STDOUT.puts "Just deleted session #{current_session_name.inspect}!"
    end
  end

  # Prompts the user to rename the current session interactively.
  #
  # This method manages a sophisticated renaming workflow:
  # 1. It presents an interactive prompt using `ask?`.
  # 2. If the user provides an empty string, it attempts to automatically
  #    derive a new name using `derive_session_name`.
  # 3. After derivation, it uses `redo` to re-prompt the user, now
  #    pre-filling the prompt with the newly suggested name.
  # 4. If the user provides an arbitrary string, the session is renamed.
  # 5. If the user interrupts (e.g., via `C-c`), the process is cancelled.
  #
  # @note The use of `1.times do` and `redo` ensures a single-retry
  #   capability for automatic name derivation.
  def rename_session
    name = nil
    1.times do
      derived = false
      prefill ||= session.name
      name = ask?(
        prompt: "❓ Enter the new name for the session (C-u ⇒ auto, C-c ⇒ cancel): ",
        prefill:
      )
      if name.nil?
        STDERR.puts "\nInterrupt: Session renaming was cancelled."
        return
      end
      if name.empty?
        if derived
          break
        else
          derived = true
          if prefill = derive_session_name.full?
            redo
          end
        end
      end
    end
    if name && session.update(name:)
      STDOUT.puts "Renamed current session to #{name.inspect}."
    elsif name == session.name
      STDOUT.puts "Keeping the old name #{name.inspect}."
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
        prompt:  prompt(:session_summarize).to_s % {
          role: message.role, unit:, content: message.content
        }
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
    generate(prompt: prompt(:session_title).to_s % { length:, content: }).response.full? do |name|
      name = name.
        gsub(/(\A(\s|[^A-Za-z])+|(\s|[^A-Za-z])+\z)/m, '').
        gsub(/\s+/, ' ')
      Kramdown::ANSI::Width.truncate(name, length:)
    end
  end


  # Closes the current session by persisting final messages and releasing
  # the process lock. This should be called during application shutdown
  # or when switching sessions to ensure the session is available for
  # future instances.
  def session_close
    store_messages_in_session
    session.unlock
  end

  # Changes to a different session, saving the current one and loading the new
  # one.
  #
  # @param name [String] the name or ID of the session to switch to
  def change_session(name)
    name.full? or name = ??
    loop do
      if chosen_session = choose_session(name, offer_new_session: true)
        if chosen_session.nil? || chosen_session == session
          confirm?(prompt: "\n⏎  Same session chosen, Press any key to continue (%s). ", timeout: 3)
          break
        end
        session_close
        @session = chosen_session
        messages.read_conversation_jsonl(session.messages.to_s)
        session.current_collection.full? { set_current_collection(_1) }
        session.current_model.full? { use_model(_1) }
        session.default_persona_id.full? { set_default_persona_name(_1) }
        session.current_system_prompt.full? { set_current_system_prompt(_1) }
        session.working_directory = Dir.pwd
        if session.lock?
          info_session
          break
        else
          confirm?(prompt: "\n⏎  Could not switch, Press any key to continue (%s). ", timeout: 3)
          redo
        end
      else
        STDOUT.puts "Canceled."
        break
      end
    end
  end

  # Finds or selects a session based on a name, ID, or pattern.
  #
  # @param session_name [String] the name, ID, or pattern to search for
  # @param except_id [String, Integer, nil] an ID to exclude from the search results
  # @return [OllamaChat::Database::Models::Session, nil] the chosen session or nil
  def choose_session(session_name, except_id: nil, offer_new_session: false)
    session_name = session_name.to_s
    session_query = models::Session
    if except_id
      session_query = session_query.where(Sequel[:id] !~ except_id)
    end
    if session_name =~ /\A\d+\z/ and
      session = session_query.first(id: session_name)
    then
      return session
    end
    selector = if session_name =~ /\A\?+(.*)\z/
                 session_name = nil
                 Regexp.new($1)
               end
    if session_name and session = session_query.first(name: session_name)
      session
    elsif selector
      now = Time.now
      sessions = session_query.order(Sequel.desc(:updated_at)).map { |session|
        duration    = session.age(now:)
        size_bytes  = session.messages.to_s.size
        tokens      = OllamaChat::Utils::TokenEstimator.estimate(size_bytes)
        tokens_size = format_tokens(tokens)
        count       = session.messages.to_s.count(?\n)
        SearchUI::Wrapper.new(
          session.name,
          display: "#{session.name} 🆔#{session.id} 📨#{count} 🧩#{tokens_size} ⏳#{duration}"
        )
      }
      selector and sessions = sessions.select { _1 =~ selector }
      session_name = if sessions.size == 1
                       sessions.first.value
                     else
                       offer_new_session and sessions.unshift(SearchUI::Wrapper.new('[new]', display: '[NEW]'))
                       sessions = sessions.unshift(SearchUI::Wrapper.new('[exit]', display: '[EXIT]'))
                       value = OllamaChat::Utils::Chooser.choose(sessions)&.value
                       if value == '[new]'
                         return new_session
                       end
                       value unless value == '[exit]'
                     end
      if session_name
        session_query.first(name: session_name)
      end
    end
  end
end
