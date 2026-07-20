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
        es = OllamaChat::TokenEstimator.estimate(s.messages.to_s)
        table << [
          s.id.to_s,
          name,
          es.bytes_formatted,
          es.tokens_formatted,
          s.messages.to_s.count(?\n),
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
    size_bytes     = session.messages.to_s.size
    es             = OllamaChat::TokenEstimator.estimate(size_bytes)
    messages_count = session.messages.to_s.count(?\n)
    output.puts "#{bold{session.name}} (#{italic{session.id}}), #{es.bytes_formatted}/#{es.tokens_formatted}, #{messages_count} messages"
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
      if models::Session.where(name: session_name).first
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
    @previous_session_id = @session.id
    @session = new_session
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
    nil
  end

  # Duplicates the current session into a new one.
  #
  # This method creates a copy of the current session's attributes and
  # prompts the user for a new name and whether to clear the duplicated
  # session's message history.
  def duplicate_session
    name = determine_valid_new_name_for_session(
      'to create', default_name: session.name
    ) or return
    old_session = session
    old_session.unlock
    @session = session.duplicate
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
    nil
  end

  # Sets up the current session based on command-line options or the last used
  # session.
  #
  # @return [OllamaChat::Database::Models::Session] the initialized session
  def setup_session
    @session = if session_name = @opts[?l]
                 choose_session(session_name,  offer_new_session: true)
               elsif @opts[?n]
                 new_session
               else
                 preferred_session
               end
    session or abort "No session named #{bold{session_name.inspect}} found."
    if session.lock?
      session_apply
    else
      raise OllamaChat::OllamaChatError,
        "Could not lock session #{session.id} #{session.errors.full?(:inspect)}"
    end
  end

  def session_apply
    session.update(working_directory: Dir.pwd)
    init_history
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
    if chosen_session = choose_session(??, except_id: current_session_id, offer_new_session: true)
      chosen_session.save
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
        if exists = models::Session.where(name:).first
          STDOUT.puts "Session with name #{name.inspect} already exists."
        else
          session.update(name:)
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
  # @param pretty [Boolean] whether to format the summary in markdown (default: false)
  # @param sentence [Boolean] whether to summarize each message in one sentence (default: false)
  # @param block [Proc] a block to handle each summary fragment
  # @return [String, nil] the session summary or nil if empty
  def summarize_session(pretty: false, sentence: false, &block)
    unit                  = sentence ? 'sentence' : 'paragraph'
    contents              = []
    messages_to_summarize = messages.each_message
    messages_to_summarize = messages_to_summarize.with_infobar(
      label:   'Summarizing message',
      total:   messages_to_summarize.count,
      message: infobar_message,
    )
    messages_to_summarize.each do |message|
      message_content  = message.content.full?
      message_thinking = message.thinking.full?
      unless message_content || message_thinking
        -infobar
        next
      end
      sender_name_output = sender_name_displayed(message)
      sender_name        = sender_name_displayed(message, template: false)
      context            = contents * "\n\n"
      summary            = generate(
        prompt:  prompt(:session_summarize).to_s % {
          sender_name:, unit:, message_content:, message_thinking:, context:
        }
      )
      content = if pretty
                  '**%s**: %s' % [ sender_name_output, summary ]
                else
                  '%s: %s' % [ sender_name_output, summary ]
                end
      block&.(content)
      contents << content
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
  # @return [String, nil] the derived session name, or nil
  def derive_session_name(length: 128)
    content = messages.each_message.inject('') do |c, message|
      message.content.present? or next c
      sender_name = sender_name_displayed(message)
      c << "%s: %s\n\n" % [ sender_name, message.content ]
    end
    prompt = prompt(:session_title).to_s % { length:, content: }
    generate(prompt:).full? do |name|
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
    links.sync
    save_history
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
      if chosen_session = choose_session(name, offer_new_session: true)
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
        messages.read_conversation_jsonl(session.messages.to_s)
        repair_group_uuids
        set_current_collection(session.current_collection.full? || :default)
        session.current_model.full? { use_model(_1) }
        set_default_persona_name(session.default_persona_name.full? || :none)
        set_current_system_prompt(session.current_system_prompt.full? || 'default')
        if session.lock?
          session_apply
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
    if previous_session_id && previous_session_id != session.id
      @previous_session_id = previous_session_id
    end
    session.update(working_directory: Dir.pwd)
  end

  # Finds or selects a session based on a name, ID, or pattern.
  #
  # @param session_name [String] the name, ID, or pattern to search for
  # @param except_id [String, Integer, nil] an ID to exclude from the search results
  # @param offer_new_session [Boolean] whether to offer creating a new session
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
        duration = session.age(now:)
        es       = OllamaChat::TokenEstimator.estimate(session.messages.to_s)
        count    = session.messages.to_s.count(?\n)
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
                       offer_new_session and sessions.unshift(SearchUI::Wrapper.new('[new]', display: '[NEW]'))
                       sessions = sessions.unshift(SearchUI::Wrapper.new('[exit]', display: '[EXIT]'))
                       value = choose_entry(sessions, prompt: 'Select a chat session: %s')&.value
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
