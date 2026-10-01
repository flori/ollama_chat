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
    @documents.find_where(
      query.first(config.embedding.model.context_length),
      tags:,
      prompt:         config.embedding.model.prompt?,
      text_size:,
      text_count:,
      min_similarity:
    )
  end

  # Reranks a set of records using the LLM with the `rerank` prompt.
  #
  # @param query [String] the original search query
  # @param records [Array<Documentrix::Utils::TagResult>] candidate records
  #
  # @return [Array<Documentrix::Utils::TagResult>] filtered records
  def rerank_records(query, records)
    candidates = records.each_with_index.map { |r, i|
      "[#{i}] #{truncate(r.text.strip, length: 300)}"
    }.join("\n")

    rerank_prompt = prompt('rerank') or
      raise "missing prompt 'rerank'"
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
end
