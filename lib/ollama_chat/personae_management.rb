module OllamaChat
  # Module for managing personas in Ollama chat application
  #
  # This module provides functionality to manage persona files, including
  # creating, reading, updating, and deleting persona definitions stored as
  # Markdown files in the personae directory.
  module PersonaeManagement
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
    # @return [Pathname] Path to the backups subdirectory within personae directory
    #
    # @note The directory is created automatically if it doesn't exist
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

    def setup_persona_from_opts
      @persona_setup and return
      @persona_setup = true
      if persona = @opts[?p].full? { Pathname.new(_1) }
        if persona.extname == '.md'
          pathname = persona
        else
          pathname = personae_directory + (persona.to_s + '.md')
        end
        if pathname.exist?
          play_persona_file pathname
        end
      end
    end

    # Returns a sorted list of available persona file names.
    #
    # This method scans the personae directory for Markdown files and
    # returns their basenames sorted alphabetically.
    #
    # @return [Array<String>] Sorted array of persona filenames without extension
    def available_personae
      personae_directory.glob('*.md').map(&:basename).sort
    end

    # Creates a new persona file interactively.
    #
    # The method prompts the user to enter a name for the persona, creates an empty Markdown
    # file with that name in the personas directory (if it does not already exist), opens
    # the file in the configured editor, and finally returns the result of calling
    # `#personae_result` on the created file.
    #
    # @return [String] The JSON string returned by `#personae_result`, or nil
    #   if the user cancels.
    def add_persona
      persona_name = ask?(
        prompt: "Enter the name of the new persona (or press return to cancel): "
      ).full? or return

      pathname = personae_directory + "#{persona_name}.md"

      unless pathname.exist?
        File.write pathname, config.prompts.persona
      end

      edit_file(pathname)

      personae_result(pathname.basename)
    end

    # Generates the backup pathname for a persona file with timestamp.
    #
    # Creates a unique backup filename with the persona name, timestamp, and
    # .md.bak extension. The timestamp format is YYYYMMDDHHMMSS for precise
    # identification of backup versions.
    #
    # @param persona [String] The persona name to create a backup path for
    # @return [Pathname] The full path to the backup file
    #
    # @note The timestamp ensures each backup has a unique filename when
    #   multiple backups of the same persona exist
    def persona_backup_pathname(persona)
      timestamp = Time.now.strftime('%Y%m%d%H%M%S')
      personae_backup_directory + (persona.sub_ext('').to_s + ?- + timestamp + '.md.bak')
    end

    # Interactive method to delete an existing persona with backup functionality.
    #
    # Prompts the user to select a persona, asks for confirmation, and creates
    # a timestamped backup of the persona file before deletion.
    #
    # @return [String] Returns a JSON object with deletion status on success,
    #   or nil if no persona was selected or deletion was cancelled
    def delete_persona
      if persona = choose_persona
        persona         = persona
        pathname        = personae_directory + persona
        backup_pathname = persona_backup_pathname(persona)
        if pathname.exist?
          STDOUT.puts "Deleting '#{bold{persona.sub_ext('')}}'..."
          STDOUT.puts "Backup will be saved to: #{backup_pathname}"

          if ask?(prompt: "Are you sure? (y/n) ") =~ /\Ay/i
            FileUtils.mv pathname, backup_pathname
            STDOUT.puts "✅ Persona #{bold{persona.sub_ext('')}} deleted successfully"
            {
              success: true,
              persona: persona.sub_ext(''),
              backup_pathname:,
            }.to_json
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
    # Prompts the user to select a persona, opens it for editing, backups the
    # old content, and returns the result after editing.
    def edit_persona
      if persona = choose_persona
        persona  = persona
        pathname = personae_directory + persona
        old_content = File.read(pathname)
        if edit_file(pathname)
          changed = File.read(pathname) != old_content
          if changed
            File.write(persona_backup_pathname(persona), old_content)
          end
          personae_result(persona)
        end
      end
    end

    # Displays detailed information about a selected persona.
    #
    # Shows the persona's profile using kramdown formatting with ansi parsing.
    def info_persona
      if persona = choose_persona
        persona_profile = load_persona_file(persona)
        use_pager do |output|
          output.puts kramdown_ansi_parse(<<~EOT)
            # Persona #{persona.sub_ext('')}
            ---
            #{persona_profile}
            ---
          EOT
        end
      end
    end

    # Lists all available persona names.
    #
    # Outputs the sorted list of persona filenames to STDOUT.
    def list_personae
      if personae = available_personae.full?
        STDOUT.puts available_personae
      else
        STDOUT.puts "No personae defined."
      end
    end

    # Interactive method to select a persona from a list.
    #
    # Allows the user to choose a persona from available options or exit.
    # Selected persona is returned if successful, nil otherwise.
    #
    # @param chosen [Set, nil] Optional set of already selected personas
    # @return [String, nil] The selected persona name or nil if user exits
    def choose_persona(chosen: nil)
      personae_list = available_personae.reject { chosen&.member?(_1) }
      if personae_list.empty?
        STDERR.puts "No personae defined."
        return
      end
      personae_list.unshift('[EXIT]')
      case chosen = OllamaChat::Utils::Chooser.choose(personae_list)
      when '[EXIT]', nil
        STDOUT.puts "Exiting chooser."
        return
      else
        chosen
      end
    end

    # Interactive method to load multiple personae for use.
    #
    # Allows sequential selection of multiple personae. Returns JSON results
    # for each loaded persona.
    def load_personae
      chosen = Set[]
      while persona = choose_persona(chosen: chosen)
        chosen << persona
      end

      if chosen.empty?
        STDOUT.puts "No persona loaded."
        return
      end

      personae_result(chosen)
    end

    # Returns a JSON hash with results for one or more personae.
    #
    # Loads the profile file for each persona and returns the results as JSON.
    #
    # @param personae [String, Array<String>] Persona name(s) to load
    # @return [String] JSON string containing persona profile information
    def personae_result(personae)
      personae = Array(personae)

      result = {}

      personae.each do |persona|
        pathname = personae_directory + persona
        pathname.exist? or next
        result[persona.sub_ext('')] = {
          pathname: ,
          profile:  pathname.read,
        }
      end

      result.to_json
    end

    # Reads and returns the content of a persona file.
    #
    # @param persona [String] The persona filename to read
    # @return [String] The content of the persona file
    def load_persona_file(persona)
      pathname = personae_directory + persona
      pathname.read if pathname.exist?
    end

    # Generates the roleplay prompt string for a persona.
    #
    # Creates a formatted prompt string that includes the persona name and profile.
    #
    # @param persona [String] The persona name to include in the prompt
    # @param persona_profile [String] The persona profile content
    # @return [String] Formatted roleplay prompt
    def play_persona_prompt(persona:, persona_profile:)
      persona_name = persona.basename.sub_ext('')
      "Roleplay as persona %{persona_name} loaded from %{persona}\n%{persona_profile}" % {
        persona_name:, persona:, persona_profile:
      }
    end

    # Initiates roleplay with a selected persona.
    #
    # Uses the persona selection and loading methods to generate the
    # appropriate roleplay prompt.
    def play_persona(pathname: nil)
      persona         = choose_persona or return
      persona_profile = load_persona_file(persona)
      play_persona_prompt(persona:, persona_profile:)
    end

    # Initiates roleplay with a persona from a specific file path.
    #
    # Uses the pathname to identify the persona, reads its content, and
    # generates the roleplay prompt.
    #
    # @param pathname [String, Pathname] The path to the persona file
    def play_persona_file(pathname)
      persona         = Pathname.new(pathname)
      persona_profile = pathname.read
      play_persona_prompt(persona:, persona_profile:)
    end
  end
end
