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
  def get_stored_model_options(model_name)
    models::ModelOptions.where(model_name:).first&.options.
      to_h.symbolize_keys_recursive
  end

  private

  # Checks if model options exist in the database for the given model name.
  #
  # @param model_name [String] the name of the model to check
  # @return [OllamaChat::Database::Models::ModelOptions, nil] the model options record or nil
  def stored_model_options_exist?(model_name)
    models::ModelOptions.where(model_name:).first
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
  def store_model_options(model_name, model_options)
    options = model_options.to_h.symbolize_keys_recursive.compact
    mo = nil
    if mo = stored_model_options_exist?(model_name)
      mo.update(options:)
    else
      mo = models::ModelOptions.create(model_name:, options:)
    end
    mo.options
  end

  # The edit_model_options method retrieves the current options for the
  # specified model, presents them to the user for editing, and returns a new
  # Ollama::Options instance based on the edited configuration.
  #
  # @param model_name [String] the name of the model whose options are to be
  #   edited.
  def edit_model_options(model_name)
    model_options      = get_stored_model_options(model_name)
    model_options      = fill_up_model_options(model_options)
    model_options_json = edit_text(JSON.pretty_generate(model_options))
    model_options      = JSON.load(model_options_json)
    store_model_options(model_name, model_options)
  rescue JSON::ParserError => e
    log(:error, "Caught in #{__method__} #{e.class}: #{e}", warn: true)
  end

  # Presents the current session's model options to the user for editing.
  #
  # @return [self] the instance of the module
  def edit_session_model_options
    model_options      = get_session_model_options
    model_options      = fill_up_model_options(model_options)
    model_options_json = edit_text(JSON.pretty_generate(model_options))
    model_options      = JSON.load(model_options_json).compact
    session.update(model_options:)
    self
  rescue JSON::ParserError => e
    log(:error, "Caught in #{__method__} #{e.class}: #{e}", warn: true)
  end

  # This method retrieves the options stored for the current session and
  # updates the active model options to match, ensuring the model behavior
  # aligns with the session's specific configuration.
  def copy_model_options_from_session
    model_name    = @model
    model_options = get_session_model_options
    store_model_options(model_name, model_options)
    STDOUT.puts "Default model options of #{bold{model_name}} were copied from session model options."
  end

  # Resets the session's model options to match the stored defaults for the
  # current model.
  def copy_model_options_to_session
    model_name = @model
    stored_model_options = get_stored_model_options(model_name)
    session.update(model_options: stored_model_options)
    STDOUT.puts "Default model options of #{bold{model_name}} were copied to session model options."
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
  #   model is retained
  # @param keep_options [Boolean] if true, session-specific model options are
  #   retained instead of reverting to model defaults.
  #
  # @return [ ModelMetadata ] the metadata for the selected model.
  def use_model(model = nil, keep_options: false)
    old_model = @model

    if model.nil?
      @model = choose_model('', @model)
    else
      @model = choose_model(model, config.model.name)
    end

    if @model_metadata = model_present?(@model)
      session.update(current_model: @model)
    else
      session.update(current_model: nil)
    end

    if old_model != @model
      default_model_options = get_default_model_options
      session_model_options = get_session_model_options
      unless stored_model_options_exist?(@model)
        store_model_options(@model, default_model_options)
      end
      stored_model_options = get_stored_model_options(@model)
      if session_model_options.blank?
        if stored_model_options.present?
          session.update(model_options: stored_model_options)
        else
          store_model_options(@model, default_model_options)
          session.update(model_options: default_model_options)
        end
      elsif !keep_options && session_model_options != stored_model_options
        STDOUT.puts <<~EOT
          ⚠️ Session model options differ from defaults for model #@model!
          Session model options:
          #{JSON.pretty_generate(session_model_options)}
          Default model options:
          #{JSON.pretty_generate(stored_model_options)}
        EOT
        if confirm?(
            prompt: "❓ Overwrite session model options with defaults? (y/n) ", yes: /\Ay/i
          )
        then
          session.update(model_options: stored_model_options)
        end
      end
    end

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
  #
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
        choose_entry(models)&.value || current_model
      else
        cli_model || current_model
      end
  ensure
    connect_message(model, ollama.base_url)
  end
end
