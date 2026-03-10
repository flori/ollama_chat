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
  class ModelMetadata < Struct.new(:name, :system, :capabilities)
    # Checks if the given capability is included in the object's capabilities.
    #
    # @param capability [String] the capability to check for
    # @return [true, false] true if the capability is present, false otherwise
    def can?(capability)
      Array(capabilities).member?(capability)
    end
  end

  private

  # The model_present? method checks if the specified Ollama model is
  # available.
  #
  # @param model [ String ] the name of the Ollama model
  #
  # @return [ ModelMetadata, FalseClass ] if the model is present,
  #   false otherwise
  def model_present?(model)
    ollama.show(model:) do |md|
      return ModelMetadata.new(
        model,
        md.system,
        md.capabilities,
      )
    end
  rescue Ollama::Errors::NotFoundError
    false
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
  private def model_with_size(model)
    formatted_size = Term::ANSIColor.bold {
      Tins::Unit.format(model.size, unit: ?B, prefix: 1024, format: '%.1f %U')
    }
    SearchUI::Wrapper.new(model.name, display: "#{model.name} #{formatted_size}")
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
  #
  # @return [ ModelMetadata ] the metadata for the selected model.
  def use_model(model = nil)
    if model.nil?
      @model = choose_model('', @model)
    else
      @model = choose_model(model, config.model.name)
    end

    @model_metadata = pull_model_unless_present(@model)

    if think? && !@model_metadata.can?('thinking')
      think_mode.selected = 'disabled'
    end

    if tools_support.on? && !@model_metadata.can?('tools')
      tools_support.set false
    end

    @model_metadata
  end

  # The choose_model method selects a model from the available list based on
  # CLI input or user interaction.
  # It processes the provided CLI model parameter to determine if a regex
  # selector is used, filters the models accordingly, and prompts the user to
  # choose from the filtered list if needed.
  # The method ensures that a model is selected and displays a connection
  # message with the chosen model and base URL.
  def choose_model(cli_model, current_model)
    selector = if cli_model =~ /\A\?+(.*)\z/
                 cli_model = ''
                 Regexp.new($1)
               end
    models = ollama.tags.models.sort_by(&:name).map { |m| model_with_size(m) }
    selector and models = models.select { _1.value =~ selector }
    model =
      if models.size == 1
        models.first
      elsif cli_model == ''
        OllamaChat::Utils::Chooser.choose(models)&.value || current_model
      else
        cli_model || current_model
      end
  ensure
    connect_message(model, ollama.base_url)
  end
end
