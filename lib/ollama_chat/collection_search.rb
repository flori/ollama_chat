# Shared collection search primitives for document retrieval and LLM
# reranking.
#
# Extracted from {OllamaChat::Tools::SearchKnowledge} so that the
# `/collection query` command and the trigger mechanism can reuse
# the same search + rerank pipeline without duplicating logic.
module OllamaChat::CollectionSearch
  include Kramdown::ANSI::Width

  # Searches the active document collection for records matching
  # the given query.
  #
  # @param query [String] the search query
  # @param tags [Array<String>, nil] tag filter
  # @param text_size [Integer, nil] max snippet size
  # @param text_count [Integer, nil] max number of snippets
  # @param min_similarity [Float, nil] minimum similarity threshold
  #
  # @return [Array<Documentrix::Utils::TagResult>] matching records
  def find_document_records(
    query,
    tags: nil, text_size: nil, text_count: nil, min_similarity: nil
  )
    tags = Documentrix::Utils::Tags.new(
      tags, valid_tag: /\A#*([-\w.\]\[]+)/
    )
    effective_query  = query.first(
      config.embedding.model.context_length
    )
    embedding_prompt = config.embedding.model.prompt?
    log(
      :info, 'Embedding search request',
      data: {
        url:        embedding_ollama.base_url,
        model:      config.embedding.model.to_h,
        collection: collection,
        query:      effective_query,
        prompt:     embedding_prompt,
      }
    )
    records = @documents.find_where(
      effective_query,
      tags:,
      prompt:         embedding_prompt,
      text_size:,
      text_count:,
      min_similarity:
    )
    log(
      :info, 'Embedding search response',
      data: {
        url:          embedding_ollama.base_url,
        collection:   collection,
        query:        effective_query,
        result_count: records.size,
        top:          records.first&.similarity&.round(4),
      }
    )
    records
  end

  # Reranks a set of records using the LLM with the `rerank` prompt.
  #
  # @param query [String] the original search query
  # @param records [Array<Documentrix::Utils::TagResult>] candidate records
  # @param prompt_name [String, nil] the prompt template to use for
  #   reranking; defaults to `'rerank'`
  # @return [Array<Documentrix::Utils::TagResult>] filtered records
  def rerank_records(query, records, prompt_name: nil)
    candidates = records.each_with_index.map { |r, i|
      "[#{i}] #{r.tags_set.to_s(link: false)} #{truncate(r.text.squeeze, length: 300)}"
    }.join("\n")

    prompt_name ||= 'default'
    rerank_prompt = prompt(prompt_name, context: 'rerank') or
      raise 'missing prompt %s' % prompt_name.inspect
    rerank_prompt = rerank_prompt.to_s
      .named_placeholders_interpolate({ query:, candidates: })

    begin
      if response = generate(prompt: rerank_prompt).full?
        indices = response.scan(/\d+/).map(&:to_i)
          .select { |i| (0...records.size).include?(i) }
        records = records.values_at(*indices) if indices.any?
      end
    rescue => e
      log(:error, e, data: { context: 'rerank' })
    end
    records
  end

  # Injects relevant snippets from the session's trigger collection
  # into the conversation as a tool message.
  #
  # Reads the first entry of the session's `trigger` hash, performs a
  # vector search in the configured collection, reranks the candidates
  # via the LLM, and appends a `trigger_inject` tool message containing
  # the surviving snippets (text, similarity, tags). The message is
  # grouped with the current user message via `group_uuid`.
  #
  # @param content [String] the parsed user message text used as the
  #   search query
  # @param group_uuid [String, nil] the group UUID for message grouping
  #   (shared with the user message and runtime-info message)
  #
  # @return [self, nil] self if snippets were injected, nil if no
  #   trigger is configured, the trigger or embedding is disabled, the
  #   collection or prompt is missing, or no snippets survived reranking
  def trigger_inject(content, group_uuid:)
    embedding.on? or return
    trigger = session.trigger&.first or return
    collection, config = trigger
    unless config['enabled']
      log(:info, 'Trigger for collection %s disabled.' % collection)
      return
    end
    unless col = database_collection?(collection)
      log(:error, 'Unknown collection named %s' % collection)
      return
    end
    prompt_name = config['prompt_name']
    unless rerank_prompt = prompt(prompt_name, context: 'rerank').full?(:to_s)
      log(
        :error, 'Unknown rerank prompt named %s' % prompt_name,
        data: { config: }
      )
      return
    end
    records = []
    switch_collection(collection) do
      records = find_document_records(content, text_count: config['text_count'])
      records.empty? and return
      pre_rerank = records.size
      records    = rerank_records(content, records, prompt_name:)
      log(
        :info,
        'Trigger: %d/%d passed rerank for %s' % [ records.size, pre_rerank, collection ],
        data: {
          collection:,
          prompt_name:,
          records: records.map { |r|
            {
              text:       r.text,
              similarity: r.similarity&.round(4),
              tags:       r.tags_set.to_s(link: false)
            }
          }
        })
      records.empty? and return
    end
    snippets = records.map { |record|
      {
        text:       record.text,
        similarity: record.similarity.to_f,
        tags:       record.tags_set.to_s(link: false),
      }
    }
    message_content = {
      prompt: prompt('snippets_trigger').to_s,
      collection: {
        name:        collection,
        description: col.description&.to_s,
      },
      snippets:
    }.to_json
    tool_name       = 'trigger_inject'
    messages << OllamaChat::Message.new(
      role:        'user',
      tool_name:   ,
      sender_name: tool_name,
      content:     message_content,
      group_uuid:
    )
    self
  end
end
