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
    es = session.estimate_tokens # We just use the formatted bytecount
    log(:info, "Messages stored in session", data: {
      session_id:    session.id,
      size:          es.bytes_formatted,
      context_usage: ,
      messages:      session.count_messages
    })
    self
  end

  # Persists a collection of links to the session in the database.
  #
  # This method serializes the links into JSONL format and updates the
  # `links` attribute of the current session.
  #
  # @param links [Enumerable] The collection of links to save.
  def store_links_in_session(links)
    output = StringIO.new
    OllamaChat::Utils::JSONJSONLIO.new('as.jsonl').write_io(
      output:, collection: links
    )
    session.update(links: output.string)
    log(:info, "Links stored in session", data: { session_id: session.id, count: links.count })
    self
  end

  # Loads the collection of links from the current session.
  #
  # This method reads the `links` attribute from the session and
  # deserializes it from JSONL format.
  #
  # @return [Array<String>] The list of links associated with the session.
  def load_links_from_session
    input = StringIO.new(session.links)
    OllamaChat::Utils::JSONJSONLIO.new('as.jsonl').read_io(input:)
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
    models::Session.with_defaults(self)
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

  # Returns the session associated with the stored @previous_session_id,
  # provided the session exists in the database and is not currently locked.
  #
  # @return [OllamaChat::Database::Models::Session, nil] the previous session
  #   if it exists and is unlocked, otherwise nil
  def previous_session
    @previous_session_id  or return
    prev = models::Session.where(id: @previous_session_id).first or return
    prev.locked? and return
    prev
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
        name        = Kramdown::ANSI::Width.truncate(s.name, length: 32)
        name        = session.id == s.id ? bold { name } : name
        name        = if pid = s.locked?
                        if pid == $$
                          "#{name} 🔓"
                        else
                          "#{name} 🔐"
                        end
                      else
                        name
                      end
        es = s.estimate_tokens
        table << [
          s.id.to_s,
          name,
          es.bytes_formatted,
          es.tokens_formatted,
          s.count_messages,
          s.age(now:),
        ]
      end
      table.align_column 0, :right
      table.align_column 2, :left
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
    es             = messages.full_estimate_tokens
    messages_count = session.count_messages
    output.puts "#{bold{session.name}} (#{italic{session.id}}), "\
      "#{es.tokens_formatted} (#{es.bytes_formatted}), "\
      "#{messages_count} messages"
  end

  # Interactively prompts the user for a unique session name.
  #
  # This method will keep prompting the user until a name is provided that
  # does not already exist in the database, or until the user cancels.
  #
  # @param action [String] a description of the action being performed
  # @param default_name [String, nil] an optional prefill value for the prompt
  # @return [String, nil] the unique session name, or nil if cancelled
  def determine_valid_new_name_for_session(action, default_name: nil)
    session_name = nil
    loop do
      session_name = ask?(
        prompt: "❓ Enter new session name #{action}, C-c ⇒ cancel: ",
        prefill: default_name
      )
      if session_name.blank?
        STDOUT.puts "Cancelled."
        return nil
      end
      if models::Session.where(name: session_name).present?
        STDOUT.puts "Session named #{bold{session_name}} already exists."
      else
        break
      end
    end
    session_name
  end

  # Creates and activates a new session with a unique name.
  #
  # This method prompts for a name, initializes a new session record, locks it,
  # and sets up the associated model and options.
  #
  # @return [nil]
  def set_new_session
    name = switch_history(:session_name) do
      determine_valid_new_name_for_session('to create')
    end
    session_close
    previous_session_id = @session.id
    @session = new_session
    set_previous_session_on_change(previous_session_id)
    session.lock? or raise OllamaChat::OllamaChatError,
      "Could not lock session #{session.id} #{session.errors.full?(:inspect)}"
    if name.full?
      session.update(name:)
    else
      session.touch
    end
    session_apply
    messages.clear
    session.current_model.full? {
      use_model(_1)
      copy_model_options_to_session
    }
    log(:info, "New session created", data: { session_id: session.id, name: session.name })
    nil
  ensure
    session.lock
  end

  # Duplicates the current session into a new one.
  #
  # This method creates a copy of the current session's attributes and
  # prompts the user for a new name and whether to clear the duplicated
  # session's message history.
  def duplicate_session
    name = switch_history(:session_name) do
      determine_valid_new_name_for_session(
        'to create', default_name: session.name
      )
    end or return
    old_session = session
    old_session.unlock
    @session = session.duplicate
    set_previous_session_on_change(old_session.id)
    session.update(name:)
    session.lock? or raise OllamaChat::OllamaChatError,
      "Could not lock session #{session.id} #{session.errors.full?(:inspect)}"
    confirm?(
      prompt: "🔔 Clear messages of duplicated session? (y/n) ",
      yes: /\Ay/i
    ) and messages.clear
    session.current_model.full? {
      use_model(_1)
      copy_model_options_to_session
    }
    log(:info, "Session duplicated", data: { session_id: session.id, name: session.name, old_session_id: old_session.id })
    nil
  end

  # Sets up the current session based on command-line options or the last used
  # session.
  #
  # @return [OllamaChat::Database::Models::Session] the initialized session
  def setup_session
    @session = if session_name = @opts[?l]
                 choose_session(session_name,  allow_new: true)
               elsif @opts[?n]
                 new_session
               else
                 preferred_session
               end
    session or abort "No session named #{bold{session_name.inspect}} found."
    if session.lock?
      messages.read_conversation_jsonl(session.messages.to_s)
      session_apply
    else
      raise OllamaChat::OllamaChatError,
        "Could not lock session #{session.id} #{session.errors.full?(:inspect)}"
    end
  end

  def session_apply
    session.update(working_directory: Dir.pwd)
    init_history
    repair_group_uuids
    session
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
    chosen = choose_session(??, except_id: current_session_id, allow_new: true, exit_app: true)
    if chosen == :quit_app
      STDOUT.puts "Exiting application."
      exit 0
    end
    if chosen
      chosen.save
      confirm?(
        prompt: "🔔 Delete session #{current_session_name.inspect} (#{current_session_id})? (y/n) ",
        yes: /\Ay/i
      ) or return
      change_session(chosen.id)
      models::Session.where(id: current_session_id).destroy
      log(:info, "Session deleted", data: { session_id: current_session_id, name: current_session_name })
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
    switch_history(:session_name) do
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
      if name == session.name
        STDOUT.puts "Keeping the old name #{name.inspect}."
      elsif name.present?
        if exists = models::Session.where(name:).present?
          STDOUT.puts "Session with name #{name.inspect} already exists."
        else
          session.update(name:)
          log(:info, "Session renamed", data: { session_id: session.id, new_name: name })
          STDOUT.puts "Renamed current session to #{name.inspect}."
        end
      else
        STDERR.puts "Could not rename current session!"
      end
    rescue Sequel::UniqueConstraintViolation
      STDERR.puts "Could not rename session to #{name.inspect}, already exists!"
    end
  end

  # Generates a summary of the current session's conversation.
  #
  # @param sentence [Boolean] whether to summarize each message in one sentence (default: false)
  # @param block [Proc] a block to handle each summary fragment
  # @return [String, nil] the session summary or nil if empty
  def summarize_session(sentence: false, &block)
    unit                  = sentence ? 'sentence' : 'paragraph'
    contents              = []
    messages_to_summarize = messages.each_message
    messages_to_summarize = messages_to_summarize.with_infobar(
      label:   'Summarizing message',
      total:   messages_to_summarize.count,
      message: infobar_message,
    )
    messages_to_summarize.each do |message|
      message_content = message.content.full?
      unless message_content
        -infobar
        next
      end
      sender_name_output = sender_name_displayed(message)
      sender_name        = sender_name_displayed(message, template: false)
      context            = contents * "\n\n"
      summary            = generate(
        prompt:  prompt(:session_summarize).to_s % {
          sender_name:, unit:, message_content:, context:
        }
      )
      content = '**%s**: %s' % [ sender_name_output, summary ]
      block&.(content)
      contents << content
      +infobar
    end
    contents.empty? and return

    contents.unshift(%{# Summary of session "#{session.name}"})
    contents * "\n\n"
  end

  # Summarizes the conversation and displays or saves the result.
  #
  # @param sentence [Boolean] summarize each message in one sentence (default: false)
  # @param save [Boolean] save to file instead of pager (default: false)
  def summarize_conversation(sentence: false, save: false)
    if save
      filename = ask_for_filename?(action: 'for summarization') or return
      should_overwrite?(filename) or return
      summary = summarize_session(sentence:) do |content|
        infobar.puts kramdown_ansi_parse(content)
      end
      if summary.full?
        filename.write(summary)
        STDOUT.puts "File successfully written."
      else
        STDERR.puts "Nothing to summarize!"
      end
    else
      summary = summarize_session(sentence:) do |content|
        infobar.puts kramdown_ansi_parse(content) << ?\n
      end
      if summary.full?
        use_pager do |output|
          output.puts kramdown_ansi_parse(summary)
        end
      else
        STDERR.puts "Nothing to summarize!"
      end
    end
  end

  # Generates a report document for the current session's conversation.
  #
  # Uses a user-selected prompt template from the 'session' context
  # (e.g. coding_brief, roleplay_story) to produce a single cohesive
  # document describing the session. Uses `compacted_messages` (summary +
  # recent tail) rather than `each_message` so the interpolated content
  # stays bounded even after multiple compaction rounds.
  #
  # @param name [String, nil] specific template name (skips chooser)
  # @return [String, nil] the report or nil if empty
  def report_session(name: nil)
    content = messages.compacted_messages.inject('') do |c, message|
      message.content.present? or next c
      sender = sender_name_displayed(message)
      c << "%s: %s\n\n" % [ sender, message.content ]
    end
    content.empty? and return

    template = if name
                 prompt(name, context: 'session')
               else
                 choose_prompt(
                   context: 'session',
                   prompt: 'Which report template? %s'
                 )
               end
    template or return

    system = prompt(:report, context: 'system').to_s

    Infobar.busy(
      label: 'Generating session report…',
      frames: :braille7,
      output: STDOUT,
    ) do
      generate(system:, prompt: template.to_s % { content: }, think: true)
    end
  end

  # Generates a report and displays or saves the result.
  #
  # @param name [String, nil] specific report template name (skips chooser)
  # @param save [Boolean] save to file instead of pager (default: false)
  def report_conversation(name: nil, save: false)
    if save
      filename = ask_for_filename?(action: 'for report') or return
      should_overwrite?(filename) or return
      result = report_session(name:)
      if result.full?
        filename.write(result)
        STDOUT.puts "File successfully written."
      else
        STDERR.puts "Nothing to report!"
      end
    else
      result = report_session(name:)
      if result.full?
        use_pager do |output|
          output.puts kramdown_ansi_parse(result)
        end
      else
        STDERR.puts "Nothing to report!"
      end
    end
  end

  # Derives a title for the session based on its content.
  #
  # @param length [Integer] the maximum length of the title (default: 128)
  # @return [String, nil] the derived session name, or nil
  def derive_session_name(length: 128)
    content = messages.each_message.inject('') do |c, message|
      message.content.present? or next c
      sender_name = sender_name_displayed(message)
      c << "%s: %s\n\n" % [ sender_name, message.content ]
    end
    prompt = prompt(:session_title).to_s % { length:, content: }
    Infobar.busy(
      label: 'Naming session…',
      frames: :braille7,
      output: STDOUT,
    ) do
      generate(prompt:).full? do |name|
        name = name.
          gsub(/(\A(\s|[^A-Za-z])+|(\s|[^A-Za-z])+\z)/m, '').
          gsub(/\s+/, ' ')
        Kramdown::ANSI::Width.truncate(name, length:)
      end
    end
  end

  # Synchronizes the current session state to the database.
  #
  # Persists messages, links, and history, updates the working directory,
  # and re-locks the session. Called before closing or switching sessions
  # to ensure no unsaved state is lost.
  #
  # @return [OllamaChat::Database::Models::Session] the current session
  def session_sync
    store_messages_in_session
    links.sync
    save_history
    session.working_directory = Dir.pwd
    session.lock
    session
  end

  # Closes the current session synchronizing it first and releasing the process
  # lock. This should be called during application shutdown or when switching
  # sessions to ensure the session is available for future instances.
  def session_close
    session_sync
    session.unlock
  end

  # Changes to a different session, saving the current one and loading the new
  # one.
  #
  # @param name [String] the name or ID of the session to switch to
  def change_session(name)
    name.full? or name = ??
    previous_session_id = nil
    loop do
      if chosen_session = choose_session(name, allow_new: true)
        if chosen_session.nil? || chosen_session == session
          confirm?(
            prompt: "\n⏎  Same session chosen, Press any key to continue (%s). ",
            timeout: 3
          )
          break
        end
        session_close
        previous_session_id = session.id
        @session = chosen_session
        if session.lock?
          messages.read_conversation_jsonl(session.messages.to_s)
          if current_collection = session.current_collection.full? and
            database_collection?(current_collection)
          then
            set_current_collection(current_collection)
          else
            set_current_collection(:default)
          end
          session.current_model.full? { use_model(_1) }
          set_default_persona_name(session.default_persona_name.full? || :none)
          set_current_system_prompt(session.current_system_prompt.full? || 'default')
          session_apply
          log(:info, "Session changed", data: { session_id: session.id, name: session.name, previous_session_id: })
          info_session
          break
        else
          confirm?(
            prompt: "\n⏎  Session locked: could not switch, Press any key to continue (%s). ",
            timeout: 3
          )
          redo
        end
      else
        STDOUT.puts "Cancelled."
        break
      end
    end
  ensure
    set_previous_session_on_change(previous_session_id)
    session_sync
  end

  # Records the previous session ID after a session transition.
  #
  # Stores the ID in `@previous_session_id` so that `#previous_session`
  # can later retrieve it, unless the ID refers to the currently active
  # session (i.e., the user re-selected the same session).
  #
  # @param previous_session_id [Integer, nil] the ID of the session
  #   that was active before the transition; `nil` if no transition occurred
  def set_previous_session_on_change(previous_session_id)
    if previous_session_id && previous_session_id != session.id
      @previous_session_id = previous_session_id
    end
  end

  # Finds or selects a session based on a name, ID, or pattern.
  #
  # @param session_name [String] the name, ID, or pattern to search for
  # @param except_id [String, Integer, nil] an ID to exclude from the search results
  # @param allow_new [Boolean] whether to offer creating a new session
  # @return [OllamaChat::Database::Models::Session, nil] the chosen session or nil
  def choose_session(session_name, except_id: nil, allow_new: false, exit_app: false)
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
        duration = session.age(now:)
        es       = session.estimate_tokens
        count    = session.count_messages
        locked   = if pid = session.locked?
                     if pid == $$
                       " 🔓#{pid} "
                     else
                       " 🔐#{pid} "
                     end
                   else
                     ' '
                   end
        display     = <<~EOT.strip
          #{session.name} 🆔#{session.id}#{locked}📨#{count} 🧩#{es.tokens_formatted} ⏳#{duration}
        EOT
        SearchUI::Wrapper.new(
          session.name,
          display:
        )
      }
      selector and sessions = sessions.select { _1 =~ selector }
      session_name = if sessions.size == 1
                        sessions.first.value
                      else
                        allow_new and sessions.unshift(SearchUI::Wrapper.new('[new]', display: '[NEW]'))
                        if exit_app
                          sessions.unshift(SearchUI::Wrapper.new('[quit-app]', display: '[QUIT-APP]'))
                        end
                        sessions.unshift(SearchUI::Wrapper.new('[exit]', display: '[EXIT]'))
                        value = choose_entry(sessions, prompt: 'Select a chat session: %s')&.value
                        if value == '[new]'
                          return new_session
                        elsif value == '[quit-app]'
                          return :quit_app
                        elsif value == '[exit]'
                          return nil
                        end
                        value
                      end
      if session_name
        session_query.first(name: session_name)
      end
    end
  end

  # Repairs `group_uuid` assignments in the current message list.
  #
  # Walks the message array backwards looking for user messages (that are not
  # tool calls) lacking a `group_uuid`. For each such anchor it:
  #
  # 1. Swaps a preceding `runtime_information` tool message so the user
  #    message comes first (structural invariant).
  # 2. Propagates the anchor's UUID forward to all subsequent messages until
  #    the next user message or the end of the list.
  #
  # After the backward pass, any remaining orphaned messages (e.g. system
  # messages not part of a user-led exchange) are assigned fresh UUIDs via
  # `initialize_group_uuid`.
  #
  # Persists the repaired message list via `store_messages_in_session`.
  def repair_group_uuids
    msgs = messages.messages # Direct reference to the internal array
    msgs.empty? and return

    # Work backwards to find and repair user-anchored groups
    i = msgs.size - 1
    while i >= 0
      # Find the first 'user' message from the back that lacks a group_uuid
      if msgs[i].role == 'user' && !msgs[i].tool? && msgs[i].group_uuid.nil?
        anchor_index = i
        group_uuid = msgs[anchor_index].initialize_group_uuid.group_uuid

        # 1. Structural Swap: [RuntimeInfo, User] -> [User, RuntimeInfo]
        if anchor_index > 0 && msgs[anchor_index - 1].tool_name == 'runtime_information'
          msgs[anchor_index - 1], msgs[anchor_index] = msgs[anchor_index], msgs[anchor_index - 1]
          i            -= 1
          anchor_index -= 1
        end

        # 2. Forward Propagation: Assign the same UUID to all following messages
        # until we hit another user message or the end of the list.
        ((anchor_index + 1)...msgs.size).each do |k|
          msgs[k].group_uuid and break
          msgs[k].group_uuid = group_uuid
        end

        # We just fixed a whole block; the next possible anchor is before this one.
      end
      i -= 1
    end

    # Handle any orphaned messages that aren't part of a user-led exchange,
    # e.g. system messages
    msgs.each(&:initialize_group_uuid)

    store_messages_in_session
  end
end
