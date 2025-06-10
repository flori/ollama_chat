module OllamaChat::ModelHandling

  # The model_present? method checks if the specified Ollama model is available.
  #
  # @param model [ String ] the name of the Ollama model
  #
  # @return [ String, FalseClass ] the system prompt if the model is present,
  # false otherwise
  def model_present?(model)
    ollama.show(model:) { return _1.system.to_s }
  rescue Ollama::Errors::NotFoundError
    false
  end

  # The pull_model_from_remote method attempts to retrieve a model from the
  # remote server if it is not found locally.
  #
  # @param model [ String ] the name of the model to be pulled
  #
  # @return [ nil ]
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
  # present, false otherwise.
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
end
