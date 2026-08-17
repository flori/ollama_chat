# A module that provides functionality for managing Ollama models, including
# checking model availability, pulling models from remote servers, and handling
# model presence verification.
#
# This module encapsulates the logic for interacting with Ollama models,
# ensuring that required models are available locally before attempting to use
# them in chat sessions. It handles both local model verification and remote
# model retrieval when necessary.
#
# @example Checking if a model is present
#   chat.model_present?('llama3.1')
#
# @example Pulling a model from a remote server
#   chat.pull_model_from_remote('mistral')
#
# @example Ensuring a model is available locally
#   chat.pull_model_unless_present('phi3', {})
module OllamaChat::ModelHandling

  # A simple data structure representing metadata about a model.
  #
  # @attr_reader name [String] the name of the model
  # @attr_reader system [String] the system prompt associated with the model
  # @attr_reader capabilities [Array<String>] the capabilities supported by the model
  # @attr_reader families [Array<String>] the families of the model
  class ModelMetadata < Struct.new(:name, :system, :capabilities, :families)
    # Checks if the given capability is included in the object's capabilities.
    #
    # @param capability [String] the capability to check for
    # @return [true, false] true if the capability is present, false otherwise
    def can?(capability)
      Array(capabilities).member?(capability)
    end
  end

  # Retrieves the stored model options from the database for a given model name.
  #
  # @param model_name [String] the name of the model to look up
  # @return [Hash] the model options as a hash with symbolized keys
  def get_stored_model_options(model_name, profile: nil)
    profile ||= 'default'
    models::ModelOptions.where(model_name:, profile:).first&.options.
      to_h.symbolize_keys_recursive
  end

  private

  # Checks if model options exist in the database for the given model name.
  #
  # @param model_name [String] the name of the model to check
  # @return [OllamaChat::Database::Models::ModelOptions, nil] the model options record or nil
  def stored_model_options_exist?(model_name, profile: nil)
    profile ||= 'default'
    models::ModelOptions.where(model_name:, profile:).first
  end

  # Retrieves the model options currently associated with the active session.
  #
  # @return [Hash] the session model options as a hash with symbolized keys
  def get_session_model_options
    session.model_options.to_h.symbolize_keys_recursive
  end

  # Retrieves the default model options from the application configuration.
  #
  # @return [Hash] the default model options as a hash
  def get_default_model_options
    config.model.options.to_h
  end

  # Computes the current model options as an `Ollama::Options` object.
  #
  # @return [Ollama::Options] the current model options object
  def model_options
    Ollama::Options[session.model_options.to_h.symbolize_keys_recursive]
  end

  # Fills in missing keys in a model options hash using the attributes of `Ollama::Options`.
  #
  # @param model_options [Hash] the hash containing the available model options
  # @return [Ollama::Options] an `Ollama::Options` object containing all required keys
  def fill_up_model_options(model_options)
    Ollama::Options.attributes.each_with_object(model_options) do |name, mo|
      mo[name] = model_options[name]
    end
    model_options
  end

  # Stores or updates model options in the database for a specific model.
  #
  # @param model_name [String] the name of the model to target
  # @param model_options [Hash, Ollama::Options] the options to persist
  # @return [Hash] the updated model options hash
  def store_model_options(model_name, model_options, profile: nil)
    profile ||= 'default'
    options   = model_options.to_h.symbolize_keys_recursive.compact
    mo        = nil
    if mo = stored_model_options_exist?(model_name, profile:)
      mo.update(options:)
    else
      mo = models::ModelOptions.create(model_name:, options:, profile:)
    end
    mo.options
  end

  # The edit_model_options method retrieves the current options for the
  # specified model, presents them to the user for editing, and returns a new
  # Ollama::Options instance based on the edited configuration.
  #
  # @param model_name [String] the name of the model whose options are to be
  #   edited, defaults to @model.
  def edit_model_options(model_name = nil, profile: nil)
    model_name         ||= @model
    profile            ||= 'default'
    model_options        = get_stored_model_options(model_name, profile:)
    model_options        = fill_up_model_options(model_options)
    model_options_json   = edit_text(JSON.pretty_generate(model_options))
    model_options        = JSON.load(model_options_json)
    store_model_options(model_name, model_options, profile:)
  rescue JSON::ParserError => e
    log(
      :error,
      "Model handling error",
      data: { method: __method__, error_class: e.class, error_message: e.message },
      warn: true
    )
  end

  # Presents the current session's model options to the user for editing.
  #
  # @return [self] the instance of the module
  def edit_session_model_options
    model_options        = get_session_model_options
    model_options        = fill_up_model_options(model_options)
    model_options_json   = edit_text(JSON.pretty_generate(model_options))
    model_options        = (JSON.load(model_options_json).full? || {}).compact
    session.update(model_options:)
    self
  rescue JSON::ParserError => e
    log(
      :error,
      "Model handling error",
      data: { method: __method__, error_class: e.class, error_message: e.message },
      warn: true
    )
  end

  # This method retrieves the options stored for the current session and
  # updates the active model options to match, ensuring the model behavior
  # aligns with the session's specific configuration.
  #
  # @param model_name [String, nil] the model to use; defaults to @model
  # @param profile [String, nil] the profile context for model options
  def copy_model_options_from_session(model_name = nil, profile: nil)
    profile       ||= 'default'
    model_name      ||= @model
    model_options   = get_session_model_options
    store_model_options(model_name, model_options, profile:)
    STDOUT.puts "Model options #{italic{profile}} for #{bold{model_name}} "\
      "were copied from session model options."
  end

  # Resets the session's model options to match the stored defaults for the
  # specified model.
  #
  # @param model_name [String, nil] the model to use; defaults to @model
  # @param profile [String, nil] the profile context for model options
  def copy_model_options_to_session(model_name = nil, profile: nil)
    profile              ||= 'default'
    model_name             ||= @model
    stored_model_options   = get_stored_model_options(model_name, profile:)
    session.update(model_options: stored_model_options)
    STDOUT.puts "Model options #{italic{profile}} of #{bold{model_name}} "\
      "were copied to session model options."
  end

  # Interactively copies model options from a source model/profile to the
  # current model/profile. Displays a side-by-side comparison if the
  # destination profile already exists and prompts for override confirmation.
  #
  # @param model [String] the destination model for the copied options
  def copy_model_options_profile(model)
    src_model   = choose_model('', model)
    src_profile = choose_profile_for_model(src_model) || 'default'
    dst_model   = model
    dst_profile = choose_profile_for_model(dst_model, allow_new: true, suggest: src_profile)

    src_opts = get_stored_model_options(src_model, profile: src_profile).full? or return

    dst_opts = get_stored_model_options(dst_model, profile: dst_profile)
    if dst_opts.present?
      STDOUT.puts "Profile #{italic{dst_profile}} already exists for #{bold{dst_model}}."
      STDOUT.puts "\n📥 Source (#{src_model}/#{src_profile}):"
      STDOUT.puts JSON.pretty_generate(src_opts)
      STDOUT.puts "\n📤 Destination (#{dst_model}/#{dst_profile}):"
      STDOUT.puts JSON.pretty_generate(dst_opts)

      unless confirm?(prompt: "⚠️ Override existing profile? (y/n) ", yes: /\Ay/i)
        STDOUT.puts "Cancelled."
        return
      end
    end

    store_model_options(dst_model, src_opts, profile: dst_profile)
    STDOUT.puts "✅ Copied options from #{italic{src_model}}/#{italic{src_profile}} "\
      "to #{bold{dst_model}}/#{italic{dst_profile}}."
  end

  # Interactively deletes a stored model options profile.
  #
  # If the deleted profile is the default one, it is replaced with an empty
  # options hash `{}` to ensure the model always has a valid default profile.
  #
  # @param model [String] the model whose profile should be deleted
  def delete_model_options_profile(model)
    profile = choose_profile_for_model(model) or return

    if confirm?(prompt: "🔔 Really delete profile #{bold{profile}} for #{bold{model}}? (y/n) ", yes: /\Ay/i)
      if profile == 'default'
        store_model_options(model, {}, profile:)
        STDOUT.puts "Default profile #{italic{profile}} for #{bold{model}} has been reset to empty options."
      else
        models::ModelOptions.where(model_name: model, profile:).destroy
        STDOUT.puts "Profile #{italic{profile}} for #{bold{model}} deleted."
      end
      log(:info, "Model options profile deleted", data: { model:, profile: })
    else
      STDOUT.puts "Cancelled."
    end
  end

  # Presents an interactive list of stored configuration profiles for the
  # specified model and prompts the user to select one.
  #
  # If only one profile exists for the model, it is returned immediately without
  # prompting. If the user cancels the selection or chooses `[EXIT]`, `nil` is
  # returned.
  #
  # @param model_name [String] the name of the model whose profiles are to be listed
  # @return [String, nil] the selected profile name, or `nil` if none was chosen
  def choose_profile_for_model(model_name, allow_new: false, suggest: nil)
    profiles = models::ModelOptions.where(model_name:).order(:profile).map(&:profile)

    if allow_new
      profiles.unshift(suggest) if suggest && !profiles.member?(suggest)
      profiles = [ '[EXIT]', '[NEW]' ] + profiles
    else
      profiles.unshift(suggest) if suggest && !profiles.member?(suggest)
      profiles.size < 2 and return profiles.first
      profiles = [ '[EXIT]' ] + profiles
    end

    case chosen = choose_entry(profiles, prompt: "Choose profile for #{bold{model_name}}: %s")
    when '[EXIT]', nil
      STDOUT.puts "Cancelled."
      return
    when '[NEW]'
      name = switch_history(:profile_name) do
        ask?(prompt: 'Enter new profile name: ')
      end or return
      if models::ModelOptions.where(model_name:, profile: name).present?
        STDERR.puts "Profile #{name.inspect} already exists!"
        return
      end
      name
    else
      chosen
    end
  end

  # Exports all stored model options for every model to a JSON file.
  #
  # The resulting JSON structure is:
  #   [
  #     { "model_name": "…", "profiles": [ { "profile": "…", "options": {…} } ] },
  #     …
  #   ]
  #
  # @return [Pathname, nil] the path of the written file, or nil if cancelled
  def export_model_options
    model_names = models::ModelOptions.distinct.map(&:model_name).sort
    unless model_names.any?
      STDERR.puts "❌ No model options stored yet!"
      return
    end

    payload = model_names.map do |name|
      { model_name: name,
        profiles: models::ModelOptions.where(model_name: name)
          .order(:profile).map { |m|
            { profile: m.profile, options: m.options.to_h }
          } }
    end

    filename = determine_valid_output_filename('to export model options to') or return
    filename.write(JSON.pretty_generate(payload))
    total = model_names.sum { |n|
      models::ModelOptions.where(model_name: n).count
    }
    log(:info, "Model options exported",
        data: { models: model_names, dest: filename.to_s })
    STDOUT.puts "✅ #{model_names.size} model(s), #{total} profile(s) "\
      "exported to #{filename.to_path.inspect}."
    filename
  end

  # Imports model options from a JSON file into the database.
  #
  # The JSON file must be an array of entries:
  #   [ { "model_name": "…", "profiles": [ … ] }, … ]
  #
  # If multiple models are present, the user selects which to import.
  # For each profile, if an existing record has different options, both
  # are displayed side-by-side and the user decides per-profile.
  #
  # @param filename [String, Pathname] the path to the JSON file to import
  # @return [Boolean, nil] true on success, nil if cancelled
  def import_model_options(filename)
    filename = Pathname.new(filename)
    data     = JSON.parse(filename.read)
    unless data.is_a?(Array) && data.all? { |d| d['model_name'] }
      STDERR.puts "❌ Invalid format: expected array of { 'model_name', 'profiles' }!"
      return
    end

    # Let user pick models if more than one
    if data.size > 1
      options = (['[ALL]'] + data.map { |d| d['model_name'] } + ['[EXIT]'])
      chosen  = choose_entry(options, prompt: 'Which model(s) to import? %s')
      case chosen
      when '[EXIT]', nil
        STDOUT.puts "Cancelled."
        return
      when '[ALL]'
        selected = data
      else
        selected = data.select { |d| d['model_name'] == chosen }
      end
    else
      selected = data
    end

    imported = 0
    selected.each do |entry|
      model_name = entry['model_name']
      profiles   = Array(entry['profiles'])
      STDOUT.puts "\n📦 #{bold{model_name}} (#{profiles.size} profile(s))"

      profiles.each do |profile_data|
        profile = profile_data['profile'] || 'default'
        options = profile_data['options'] || {}

        existing = stored_model_options_exist?(model_name, profile:)
        if existing
          current = existing.options.to_h.symbolize_keys_recursive
          incoming = options.to_h.symbolize_keys_recursive
          if current == incoming
            STDOUT.puts "   • #{italic{profile}}: identical, skipping."
            next
          end
          STDOUT.puts "   • #{italic{profile}}: differs!"
          STDOUT.puts "     📤 Current:"
          STDOUT.puts "       " + JSON.pretty_generate(current).sub(/^/m, '     ')
          STDOUT.puts "     📥 Incoming:"
          STDOUT.puts "       " + JSON.pretty_generate(incoming).sub(/^/m, '     ')
          unless confirm?(prompt: "     ⚠️ Overwrite? (y/n) ", yes: /\Ay/i)
            STDOUT.puts "     Skipped."
            next
          end
        end

        store_model_options(model_name, options, profile:)
        imported += 1
        STDOUT.puts "   • #{italic{profile}}: ✅"
      end
    end

    log(:info, "Model options imported",
        data: { models: selected.map { |e| e['model_name'] },
                imported:, source: filename.to_s })
    STDOUT.puts "\n✅ Imported #{imported} profile(s) "\
      "from #{filename.to_path.inspect}."
    true
  end


  # The model_present? method checks if the specified Ollama model is
  # available.
  #
  # @param model [ String ] the name of the Ollama model
  #
  # @return [ ModelMetadata, NilClass ] if the model is present,
  #   nil otherwise
  def model_present?(model)
    ollama.show(model:) do |md|
      return ModelMetadata.new(
        name:         model,
        system:       md.system,
        capabilities: md.capabilities,
        families:     md.details.families,
      )
    end
  rescue Ollama::Errors::NotFoundError
    nil
  end

  # The pull_model_from_remote method attempts to retrieve a model from the
  # remote server if it is not found locally.
  #
  # @param model [ String ] the name of the model to be pulled
  def pull_model_from_remote(model)
    STDOUT.puts "Model #{bold{model}} not found locally, attempting to pull it from remote now…"
    ollama.pull(model:)
  end

  # The pull_model_unless_present method ensures that a specified model is
  # available on the Ollama server. It first checks if the model metadata
  # exists locally; if not, it pulls the model from a remote source and
  # verifies its presence again. If the model still cannot be found, it raises
  # an UnknownModelError indicating the missing model name.
  #
  # @param model [String] the name of the model to ensure is present
  #
  # @return [ModelMetadata] the metadata for the available model
  # @raise [OllamaChat::UnknownModelError] if the model cannot be found after
  #   attempting to pull it from remote
  def pull_model_unless_present(model)
    if model_metadata = model_present?(model)
      return model_metadata
    else
      pull_model_from_remote(model)
      if model_metadata = model_present?(model)
        return model_metadata
      end
      raise OllamaChat::UnknownModelError, "unknown model named #{@model.inspect}"
    end
  end

  # The model_with_size method formats a model's size for display
  # by creating a formatted string that includes the model name and its size
  # in a human-readable format with appropriate units.
  #
  # @param model [ Object ] the model object that has name and size attributes
  #
  # @return [ Object ] a result object with an overridden to_s method
  #                     that combines the model name and formatted size
  def model_with_size(model, favourited: false)
    formatted_size = Term::ANSIColor.bold {
      format_bytes(model.size)
    }
    display = prefix_favourite("#{model.name} #{formatted_size}", favourited)
    SearchUI::Wrapper.new(model.name, display:)
  end

  # Ensures the specified model is available locally and synchronizes the
  # session's capability settings with the model's actual supported features.
  #
  # This method performs a lazy-load check: it pulls the model if it's missing
  # and then immediately validates and updates 'thinking' and 'tools' support
  # to prevent invalid API requests.
  #
  # @param model [String] the name of the model to prepare for use
  # @return [OllamaChat::ModelHandling::ModelMetadata] the metadata for the
  #   prepared model
  def prepare_model(model)
    @model_metadata = pull_model_unless_present(model)
    if think? && !@model_metadata.can?('thinking')
      think_mode.selected = 'disabled'
    end

    if tools_support.on? && !@model_metadata.can?('tools')
      tools_support.set false
    end
  end

  # Reconfigures model options for the current model and profile.
  #
  # Ensures that the session has the appropriate model options by:
  # - Storing default options if none exist for the model/profile combination
  # - Populating blank session options with stored or default values
  # - Prompting to overwrite session options if they diverge from stored defaults
  #   (only when +keep_options+ is false)
  #
  # @param profile [String, nil] The profile context for model options storage
  def reconfigure_model_options(profile:, keep_options:)
    default_model_options = get_default_model_options
    session_model_options = get_session_model_options
    unless stored_model_options_exist?(@model, profile:)
      store_model_options(@model, default_model_options, profile:)
    end
    stored_model_options = get_stored_model_options(@model, profile:)
    if session_model_options.blank?
      if stored_model_options.present?
        session.update(model_options: stored_model_options)
      else
        store_model_options(@model, default_model_options)
        session.update(model_options: default_model_options)
      end
    elsif !keep_options && session_model_options != stored_model_options
      all_profiles = models::ModelOptions.where(model_name: @model).
        order(:profile).all

      matching = all_profiles.any? do |mo|
        mo.options.ask_and_send(:symbolize_keys_recursive) == session_model_options
      end

      unless matching
        use_pager do |output|
          output.puts "⚠️ Session model options differ from current profile (#{italic{profile}}) and don't match any saved profile!"
          output.puts "\n📋 Available profiles for #{bold{@model}}:"
          all_profiles.each do |mo|
            output.puts "\n📄 #{italic{mo.profile}}:"
            output.puts JSON.pretty_generate(mo.options.ask_and_send(:symbolize_keys_recursive))
          end
        end

        if confirm?(prompt: "\n❓ Switch to an existing profile? (y/n) ", yes: /\Ay/i)
          chosen = choose_profile_for_model(@model)
          if chosen
            new_opts = get_stored_model_options(@model, profile: chosen)
            session.update(model_options: new_opts)
            STDOUT.puts "Switched to profile #{italic{chosen}}."
          end
        end
      end
    end
  end

  # The use_model method selects and sets the model to be used for the chat
  # session.
  #
  # It allows specifying a particular model or defaults to the current model.
  # After selecting, it pulls the model metadata if necessary. If think? is
  # true and the chosen model does not support thinking, the think mode
  # selector is set to 'disabled'. If tools_support.on? is true and the chosen
  # model does not support tools, tool support is disabled. Returns the
  # metadata for the selected model.
  #
  # @param model [ String, nil ] the model name to use; if omitted, the current
  #   model can be selected
  # @param keep_options [Boolean] if true, session-specific model options are
  #   retained instead of reverting to model defaults.
  #
  # @return [ ModelMetadata ] the metadata for the selected model.
  def use_model(model = nil, keep_options: false, profile: nil)
    profile   ||= 'default'
    old_model   = @model

    if model.blank?
      @model = choose_model('', @model)
    else
      @model = choose_model(model, config.model.name)
    end

    if @model_metadata = model_present?(@model)
      session.update(current_model: @model)
    else
      session.update(current_model: nil)
    end

    old_model != @model and reconfigure_model_options(profile:, keep_options:)

    log(:info, "Model switched", data: { old_model:, new_model: @model, profile: })
    @model_metadata
  end

  # Retrieves a sorted list of all available Ollama models, enriched with size
  # information and marked as favorites where applicable.
  #
  # This method fetches the list of models from the Ollama server, sorts them
  # alphabetically by name, and wraps each in a SearchUI::Wrapper for
  # consistent display in the user interface.
  #
  # @return [Array<SearchUI::Wrapper>] a sorted list of available models with
  #   metadata
  def all_models
    favs = all_favourited('model')
    ollama.tags.models.sort_by(&:name).
      map { |m| model_with_size(m, favourited: favs[m.name]) }
  end

  # The choose_model method selects a model from the available list based on
  # CLI input or user interaction.
  # It processes the provided CLI model parameter to determine if a regex
  # selector is used, filters the models accordingly, and prompts the user to
  # choose from the filtered list if needed.
  # The method ensures that a model is selected and displays a connection
  # message with the chosen model and base URL.
  #
  # @param cli_model [String] the model name or pattern provided via CLI
  # @param current_model [String] the fallback model if selection fails
  # @return [String] the selected model name
  def choose_model(cli_model, current_model)
    selector = if cli_model =~ /\A\?+(.*)\z/
                 cli_model = ''
                 Regexp.new($1)
               end
    models = all_models
    selector and models = models.select { _1.value =~ selector }
    model =
      if models.size == 1
        models.first.value
      elsif cli_model == ''
        choose_entry(
          models,
          prompt: "Which digital oracle shall we consult? %s"
        )&.value || current_model
      else
        cli_model || current_model
      end
  ensure
    connect_message(model, ollama.base_url)
  end
end
