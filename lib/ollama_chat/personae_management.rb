# Module for managing personae in Ollama chat application
#
# This module provides functionality to manage persona files, including
# creating, reading, updating, and deleting persona definitions stored as
# Markdown files in the personae directory.
module OllamaChat::PersonaeManagement
  # The initial_persona_name method retrieves the initial persona for
  # the chat session.
  #
  # @return [ String, nil ] the persona name or nil if not set
  def initial_persona_name
    session&.default_persona_name
  end

  # Retrieves the formatted roleplay prompt for the current default persona.
  #
  # @return [String, nil] The formatted persona profile or nil if none set
  def default_persona_profile
    if persona = default_persona and persona.exist?
      play_persona(persona)
    end
  end

  # Returns the name of the current default persona.
  #
  # If the default persona is set to :none or is not configured, it returns
  # nil.
  #
  # @return [String, Symbol, nil] the name of the default persona, or nil if
  #   none is set.
  def assistant
    if default_persona_name && default_persona_name != :none
      default_persona_name
    end
  end

  private

  # Returns the directory path where persona files are stored.
  #
  # The path is constructed using the XDG_CONFIG_HOME environment variable
  # for platform-agnostic configuration storage.
  #
  # @return [Pathname] Path to the personae directory
  #
  # @note The directory is created automatically if it doesn't exist
  def personae_directory
    OC::XDG_CONFIG_HOME + 'personae'
  end

  # Returns the directory path for persona backup files.
  #
  # @return [Pathname] Path to the backups subdirectory within the personae
  #   directory
  def personae_backup_directory
    personae_directory + 'backups'
  end

  # Creates the personae directory structure if it doesn't already exist.
  #
  # This method ensures both the main personae directory and the backups
  # subdirectory exist for proper file organization.
  def setup_personae_directory
    FileUtils.mkdir_p personae_backup_directory
  end

  # Sets the default persona name and updates the session.
  #
  # @param persona_name [ String, nil ] the name of the persona to set as
  #   default
  #
  # @return [ String, nil ] the set default persona name or nil if not set
  def set_default_persona_name(persona_name)
    if persona_name.present? && persona_name != :none
      @default_persona_name = Pathname.new(persona_name).basename.sub_ext('').to_path
      @session.update(default_persona_name: default_persona_name)
    else
      @session.update(default_persona_name: nil)
      @default_persona_name = nil
    end
    messages.set_system_prompt(session&.current_system_prompt.full?)
    default_persona_name
  end

  # Interactively selects a persona and sets it as the default for the session.
  #
  # This method prompts the user to choose a persona from the available list
  # using `choose_persona`. If a valid persona is selected, it updates the
  # session and the internal state via `set_default_persona_name`.
  #
  # @return [String, nil] The name of the persona that was set as default,
  #   or nil if the selection was cancelled or no persona was chosen.
  def set_default_persona
    if persona = choose_persona(none: true, prompt: 'Who would you like to talk to today? %s')
      set_default_persona_name(persona)
    end
  end

  # The default_persona_name method returns the name of the default persona.
  #
  # @return [String, nil] the name of the default persona or nil if not set
  attr_reader :default_persona_name

  # The default_persona method returns the path to the default persona file.
  #
  # @return [ Pathname, nil ] the Pathname object for the default persona file
  #   or nil if no default persona is set
  def default_persona
    if default_persona_name && default_persona_name != :none
      personae_directory.join(default_persona_name).sub_ext('.md')
    end
  end

  # Initializes the default persona for the current chat session.
  #
  # This method ensures that a default persona is configured at startup:
  # 1. If a default persona is already set, it returns immediately.
  # 2. Otherwise, it attempts to retrieve the initial persona prompt name from
  #    the session and verifies if the corresponding Markdown file exists.
  # 3. If a valid file is found, it sets it as the default persona.
  # 4. The `ensure` block guarantees that the session always has a default persona
  #    assigned, falling back to `:none` if no valid persona is found.
  #
  # @return [Pathname, String, nil] The resulting default persona path or name,
  #   or nil if no persona is set.
  def setup_persona_from_session
    default_persona and return
    if persona = initial_persona_name and
      persona_pathname = personae_directory + (persona + '.md') and
      persona_pathname.exist?
    then
      set_default_persona_name(persona_pathname)
    end
  ensure
    default_persona or set_default_persona_name(:none)
  end

  # Returns a sorted list of available persona file names.
  #
  # This method scans the personae directory for Markdown files and returns
  # their basenames sorted alphabetically.
  #
  # @return [Array<String>] Sorted array of persona filenames without extension
  def available_personae
    personae_directory.glob('*.md').map { pathname_to_persona_name(_1) }
  end

  # Helper to wrap a persona name with its favourite status for the UI.
  #
  # @param name [String] the name of the persona
  # @param favourited [Boolean] whether the persona is marked as a favourite
  # @return [SearchUI::Wrapper] a wrapper containing the original name and the
  #   decorated display string
  def persona_name_with_favourite(name, favourited)
    display = prefix_favourite(name, favourited)
    SearchUI::Wrapper.new(name, display:)
  end

  # Retrieves a list of available personae, decorated with their favourite
  # status.
  #
  # @return [Array<SearchUI::Wrapper>] a list of wrappers containing the
  #   persona name and its decorated display string
  def available_personae_names
    favs = all_favourited('persona')
    personae_directory.glob('*.md').map(&:basename).sort.map { |bn|
      persona_name = bn.sub_ext('').to_s
      persona_name_with_favourite(persona_name, favs[persona_name])
    }
  end

  # Creates a new persona file interactively.
  #
  # The method prompts the user to enter a name for the persona, creates an
  # empty Markdown file with that name in the personae directory (if it does
  # not already exist), opens the file in the configured editor, and finally
  # returns the result of calling `#personae_result` on the created file.
  def add_persona
    persona_name = ask?(
      prompt: "❓ Enter the name of the new persona (or press return to cancel): "
    ).full? or return

    pathname = personae_directory + "#{persona_name}.md"

    unless pathname.exist?
      File.write pathname, prompt(:persona).to_s
    end

    edit_file(pathname)
    nil
  end

  # Generates the backup pathname for a persona file with timestamp.
  #
  # Creates a unique backup filename with the persona name, timestamp, and
  # .md.bak extension. The timestamp format is YYYYMMDDHHMMSS for precise
  # identification of backup versions.
  #
  # @param persona [String] The persona name to create a backup for
  # @return [Pathname] The full path to the backup file
  #
  # @note The timestamp ensures each backup has a unique filename when
  #   multiple backups of the same persona exist
  def persona_backup_pathname(persona)
    timestamp = Time.now.strftime('%Y%m%d%H%M%S')
    personae_backup_directory + (persona + ?- + timestamp + '.md.bak')
  end

  # Interactive method to delete an existing persona with backup functionality.
  #
  # Prompts the user to select a persona, asks for confirmation, and creates a
  # timestamped backup of the persona file before deletion.
  #
  # @return [String] A JSON object with deletion status on success,
  #   or nil if persona was not selected or deletion was cancelled
  def delete_persona
    if persona = choose_persona(prompt: 'Which persona is no longer needed? %s')
      pathname        = persona_name_to_pathname(persona)
      backup_pathname = persona_backup_pathname(persona)
      if pathname.exist?
        STDOUT.puts "Deleting '#{bold{persona}}'..."
        STDOUT.puts "Backup will be saved to: #{backup_pathname}"

        if confirm?(prompt: "🔔 Are you sure? (y/n) ", yes: /\Ay/i)
          FileUtils.mv pathname, backup_pathname
          default_persona_name == persona and
            set_default_persona_name(:none)
          STDOUT.puts "Persona #{bold{persona}} deleted successfully"
          self
        else
          STDOUT.puts "Deletion cancelled."
          return
        end
      else
        STDOUT.puts "Persona not found."
        return
      end
    end
  end

  # Interactive method to edit an existing persona file.
  #
  # Prompts the user to select a persona, opens it for editing, backups the old
  # content, and returns the result after editing.
  #
  # @return [String, nil] persona name or nil if cancelled
  def edit_persona
    if persona = choose_persona(prompt: 'Which persona needs some polishing? %s')
      pathname = persona_name_to_pathname(persona)
      old_content = pathname.read
      if edit_file(pathname)
        changed = pathname.read != old_content
        if changed
          persona_backup_pathname(persona).write(old_content)
          ask_to_set_default_persona_name(persona)
        end
        persona
      end
    end
  end

  # Prompts the user to select a persona, copies its filesystem path to the
  # clipboard, and sets it as the prefill prompt for the next interaction.
  #
  # @param [Boolean] no_prefill Whether to skip updating the prefill prompt.
  # @return [String, nil] the filesystem path of the selected persona,
  #   or nil if the selection was cancelled.
  def select_persona_path(no_prefill: false)
    persona = choose_persona(prompt: "Which persona's path do you need? %s") or return
    path = persona_name_to_pathname(persona).to_s
    perform_copy_to_clipboard(text: path, edit: false)
    no_prefill or self.prefill_prompt = path
    path
  end

  # Backs up the content of a selected persona file.
  #
  # Prompts the user to select a persona from the available list. If a persona
  # is selected, its current content is read and saved to a designated backup
  # location using `File.write`. This ensures a safe copy is preserved before
  # any modifications are made to the original file.
  def backup_persona
    if persona = choose_persona(prompt: 'Which persona should be safely archived? %s')
      pathname        = persona_name_to_pathname(persona)
      old_content     = pathname.read
      backup_pathname = persona_backup_pathname(persona)
      backup_pathname.write(old_content)
      STDOUT.puts "Wrote backup of #{persona.to_s} to #{backup_pathname.to_s.inspect}."
    end
  end

  # Generates a formatted description of a persona, including its path and
  # profile.
  #
  # @param persona [String] The persona name.
  # @param substitute_variables [Boolean] Whether to substitute variables in the profile.
  # @return [String, nil] The formatted description or nil if the persona is not found.
  def persona_description(persona, substitute_variables: false)
    persona_path, persona_profile = load_persona_file(persona)
    if substitute_variables
      persona_profile = self.substitute_variables(persona_profile)
    end
    persona_profile or return
    <<~EOT
      # Persona #{persona}

      File #{persona_path.to_path}

      ---

      #{persona_profile}

      ---
    EOT
  end

  # Displays detailed information about a selected persona.
  #
  # Shows the persona's profile using kramdown formatting with ansi parsing.
  def info_persona
    if persona = choose_persona(prompt: 'Who would you like to learn more about? %s')
      description = persona_description(persona) or return
      use_pager do |output|
        output.puts kramdown_ansi_parse(description)
      end
    end
  end

  # Lists all available persona names in a formatted table.
  #
  # @param output [IO] the output stream to write the table to (default: STDOUT)
  def list_personae(output: STDOUT)
    use_pager do |output|
      personae = available_personae
      if personae.empty?
        STDOUT.puts "No personae defined."
        return
      end

      favs = all_favourited('persona')

      table = Terminal::Table.new
      table.style = {
        all_separators: true,
        border:         :unicode_round,
      }
      table.headings = %w[ NAME SIZE #TOK ].map { |header| bold { header } }

      personae.map do |persona_name|
        pathname = persona_name_to_pathname(persona_name)
        pathname.exist? or next
        [ pathname, pathname.size ]
      end.compact.sort_by(&:last).reverse_each do |pathname, size_bytes|
        persona_name = pathname.basename.sub_ext('').to_s
        es           = OllamaChat::TokenEstimator.estimate(size_bytes)
        is_default   = default_persona_name == persona_name
        display_name = prefix_favourite(is_default ? bold { persona_name } : persona_name, favs[persona_name])

        table << [ display_name, es.bytes_formatted, es.tokens_formatted, ]
      end

      table.align_column 1, :right
      table.align_column 2, :right
      output.puts table
    end
  end

  # Interactive method to select a persona from a list.
  #
  # Allows the user to choose a persona from available options or exit.
  # Selected persona is returned if successful, nil if user exits.
  #
  # @param chosen [Set, nil] Optional set of already selected personae
  # @param none [Boolean] whether to include a '[NONE]' option in the list
  # @param prompt [String] the prompt message to display when asking for input
  #   (default: 'Select a persona: ')
  # @return [String, Symbol, nil] The selected persona name, :none, or nil if
  #   user exits
  def choose_persona(chosen: nil, none: false, prompt: 'Select a persona: %s')
    personae_list = available_personae_names.
      reject { chosen&.member?(_1) }
    if personae_list.empty?
      STDERR.puts "No personae defined."
      return
    end
    personae_list.unshift('[NONE]') if none
    personae_list.unshift('[EXIT]')
    case persona = choose_entry(personae_list, prompt:)
    when '[EXIT]', nil
      STDOUT.puts "Exiting chooser."
      return
    when '[NONE]'
      :none
    else
      persona.value
    end
  end

  # Interactive method to load multiple personae for use.
  #
  # Allows sequential selection of multiple personae. Returns JSON results for
  # each loaded persona.
  def load_personae
    chosen = Set[]
    choose_with_state do
      while persona = choose_persona(chosen: chosen, prompt: 'Who else should join the conversation? %s')
        persona == :none and next
        chosen << persona
      end
    end

    if chosen.empty?
      STDOUT.puts "No persona loaded."
      return
    end

    personae_result(chosen)
  end

  # Compiles the descriptions for one or more personae into a single string.
  #
  # Loads the profile for each persona and concatenates their descriptions.
  #
  # @param personae [String, Array<String>] Persona name(s) to load.
  # @return [String, nil] A string containing all descriptions, or nil if the
  #   result is blank.
  def personae_result(personae)
    personae = Array(personae)

    result = +''

    personae.each do |persona|
      description = persona_description(persona, substitute_variables: true) or next
      result << description << "\n"
    end

    result.full?
  end

  # Loads a persona file from disk.
  #
  # @param persona [String] The basename of the persona (without extension)
  #
  # @return [Array<Pathname, String>] Returns the pathname and its content as a
  #   string
  def load_persona_file(persona)
    pathname = persona_name_to_pathname(persona)
    if pathname.exist?
      return pathname, pathname.read
    end
  end

  # The substitute_variables method handles the substitution of variables in
  # profiles. It replaces placeholders with actual values.
  #
  # @param profile [String] the profile string to be processed
  #
  # @return [String] the processed string with variables substituted
  def substitute_variables(profile)
    profile = profile.gsub(/%(?=[^{])/, '%%')
    profile = profile % { user: }
    profile
  end

  # Generates the roleplay prompt string for a persona.
  #
  # Creates a formatted prompt string that includes the persona name and profile.
  #
  # @param persona [String, Pathname] The persona name or path to include in
  #   the prompt
  # @return [String] Formatted roleplay prompt
  def play_persona(persona)
    pathname, profile = load_persona_file(persona)
    profile = substitute_variables(profile)
    profile_intro = <<~EOT
      Roleplay as persona %{persona} (no nead to read the file) loaded from %{pathname}

      %{profile}
    EOT
    profile_intro % {
      persona:, pathname:, profile:
    }
  end

  # Converts a persona prompt name to its full filesystem pathname.
  #
  # @param persona_name [String] The name of the persona (without extension)
  # @return [Pathname] The full path to the .md persona file
  def persona_name_to_pathname(persona_name)
    personae_directory.join(persona_name).sub_ext('.md')
  end

  # Converts a persona pathname to its prompt name.
  #
  # @param pathname [Pathname, String] The path to the persona file
  # @return [String] The persona name without extension
  def pathname_to_persona_name(pathname)
    pathname.basename.sub_ext('').to_s
  end

  # Interactively determines a valid, non-conflicting name for a new persona.
  #
  # @param action [String] The action being performed (e.g., 'to import')
  # @return [String, nil] The validated persona name or nil if cancelled
  def determine_valid_new_name_for_persona(action)
    persona_name = nil
    loop do
      persona_name = ask?(
        prompt: "❓ Enter new persona prompt name #{action}, C-c ⇒ cancel: "
      )
      if persona_name.nil?
        STDOUT.puts "Cancelled."
        return nil
      end
      if persona_name_to_pathname(persona_name).exist?
        STDOUT.puts "Persona prompt named #{bold{persona_name}} already exists."
      else
        break
      end
    end
    persona_name
  end

  # Interactively duplicates an existing persona profile to a new name.
  #
  # The process follows these steps:
  # 1. Prompts the user to select a source persona via `choose_persona`.
  # 2. Prompts the user to enter a unique name for the duplicate via
  #   `determine_valid_new_name_for_persona`.
  # 3. Copies the content from the source persona file to the new persona file.
  #
  # @return [self, nil] returns self on success, or nil if the operation was
  #   cancelled during persona selection or name entry.
  def duplicate_persona
    persona          = choose_persona(prompt: 'Which persona shall serve as the blueprint? %s') or return
    pathname         = persona_name_to_pathname(persona)
    new_persona_name = determine_valid_new_name_for_persona('to ducplicate as') or return
    new_pathname     = persona_name_to_pathname(new_persona_name)
    new_pathname.write(pathname.read)
    self
  end

  # Imports a persona from a Markdown file, prompting for a new name.
  #
  # @param pathname [Pathname, String] The path to the file to import
  # @return [String, nil] The name of the imported persona or nil if cancelled
  def import_persona(pathname)
    content          = pathname.read
    persona_name     = determine_valid_new_name_for_persona('to import') or return
    persona_pathname = persona_name_to_pathname(persona_name)
    persona_pathname.write(content)
    persona_name
  end

  # Imports a character persona from JSON data, prompts for a name,
  # and saves the resulting Markdown profile to disk.
  #
  # @param json_data [String] The raw character data in JSON format.
  # @return [String, nil] The name of the created persona if successful,
  #   or nil if the process was cancelled or failed.
  def import_persona_from_json(json_data)
    persona_name = determine_valid_new_name_for_persona('to import from JSON/PNG') or return
    markdown = convert_json_character_to_markdown(json_data, persona_name)
    persona_pathname = persona_name_to_pathname(persona_name)
    persona_pathname.write(markdown)
    persona_name
  end

  # Transforms raw character data (JSON or YAML) into a high-fidelity,
  # structured Markdown persona profile using the persona architect prompt and
  # the current persona template.
  #
  # This method leverages the LLM to interpret raw attributes and expand them
  # into evocative prose, ensuring the final output conforms to the system's
  # standard persona structure. It also normalizes placeholders: {{user}} is
  # converted to %{user} for runtime personalization, and {{char}} is replaced
  # with the actual character name provided.
  #
  # @param character [String] the raw character data in JSON format
  # @param persona_name [String] the name of the character to replace {{char}} with
  # @return [String] the resulting structured Markdown persona profile
  def convert_json_character_to_markdown(character, persona_name)
    generate(
      prompt:  prompt(:persona_architect).to_s % {
        character:,
        persona_template: prompt(:persona).to_s
      }
    ).gsub(/{{user}}/i, '%{user}').gsub(/{{char}}/i, persona_name)
  end

  # Interactively exports a persona profile to a specified file.
  #
  # The process follows these steps:
  # 1. Prompts the user to select a persona via `choose_persona`.
  # 2. Displays the persona's current content to the terminal.
  # 3. Prompts for a destination filename via
  #   `determine_valid_output_filename`.
  # 4. Writes the persona content to the chosen file.
  #
  # @return [self, nil] returns self if the export was successful, or nil if
  #   the process was cancelled during persona selection or filename entry.
  def export_persona
    persona  = choose_persona(prompt: 'Which persona are you taking with you? %s') or return
    pathname = persona_name_to_pathname(persona)
    content  = pathname.read
    STDOUT.puts kramdown_ansi_parse(
      content + "\n---"
    )
    filename = determine_valid_output_filename('to write to') or return
    filename.write(content)
    STDOUT.puts "Persona #{persona.inspect} was exported as #{filename.to_path.inspect}?"
    self
  end

  # Interactively asks the user if they want to set the specified persona as
  # the current default for the session.
  #
  # If the user confirms, the default persona is updated via
  # `set_default_persona_name`.
  #
  # @param persona_name [String] the name of the persona to potentially set as
  #   default
  # @return [Boolean] true if the persona was set as the default, false
  #   otherwise
  def ask_to_set_default_persona_name(persona_name)
    yes = confirm?(
      prompt: "🔔 Set the new persona promt as current default persona? (y/n) ",
      yes: /\Ay/i
    )
    if yes
      set_default_persona_name(persona_name)
      true
    else
      false
    end
  end
end
