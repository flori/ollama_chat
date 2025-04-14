module OllamaChat::ModelHandling
  def model_present?(model)
    ollama.show(model:) { return _1.system.to_s }
  rescue Ollama::Errors::NotFoundError
    false
  end

  def pull_model_from_remote(model)
    STDOUT.puts "Model #{bold{model}} not found locally, attempting to pull it from remote now…"
    ollama.pull(model:)
  end

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
