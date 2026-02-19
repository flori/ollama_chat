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
  # The model_present? method checks if the specified Ollama model is available.
  #
  # @param model [ String ] the name of the Ollama model
  #
  # @return [ String, FalseClass ] the system prompt if the model is present,
  #   false otherwise
  def model_present?(model)
    ollama.show(model:) { return _1.system.to_s }
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

  # The pull_model_unless_present method checks if the specified model is
  # present on the system.
  #
  # If the model is already present, it returns the system prompt if it is
  # present.
  #
  # Otherwise, it attempts to pull the model from the remote server using the
  # pull_model_from_remote method. If the model is still not found after
  # pulling, it exits the program with a message indicating that the model was
  # not found remotely.
  #
  # @param model [ String ] The name of the model to check for presence.
  # @param options [ Hash ] Options for the pull_model_from_remote method.
  #
  # @return [ String, FalseClass ] the system prompt if the model and it are
  #   present, false otherwise.
  def pull_model_unless_present(model, options)
    if system = model_present?(model)
      return system.full?
    else
      pull_model_from_remote(model)
      if system = model_present?(model)
        return system.full?
      else
        STDOUT.puts "Model #{bold{model}} not found remotely. => Exiting."
        exit 1
      end
    end
  rescue Ollama::Errors::Error => e
    warn "Caught #{e.class} while pulling model: #{e} => Exiting."
    exit 1
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
    result = model.name
    formatted_size = Term::ANSIColor.bold {
      Tins::Unit.format(model.size, unit: ?B, prefix: 1024, format: '%.1f %U')
    }
    result.singleton_class.class_eval do
      define_method(:to_s) { "%s %s" % [ model.name, formatted_size ] }
    end
    result
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
    selector and models = models.grep(selector)
    model =
      if models.size == 1
        models.first
      elsif cli_model == ''
        OllamaChat::Utils::Chooser.choose(models) || current_model
      else
        cli_model || current_model
      end
  ensure
    connect_message(model, ollama.base_url)
  end
end
