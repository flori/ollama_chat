# Moves application-internal prompt templates from the 'prompt' context
# to a dedicated 'internal' context.
#
# Only affects config-seeded prompts (metadata.default = true); user-created
# prompts that happen to share a name are left untouched.
Sequel.migration do
  up do
    internal_names = %w[
      embed snippets_retrieval snippets_trigger summarize
      web_embed web_import web_summarize location
      static_runtime_info dynamic_runtime_info help
      persona persona_architect context_template_suggest
      session_summarize session_title
    ]

    from(:prompts).where(
      context: 'prompt',
      name: internal_names,
      Sequel.function(:json_extract, :metadata, '$.default') => 1,
    ).update(context: 'internal')

    from(:favourites).where(
      context: 'prompt',
      name: internal_names,
    ).update(context: 'internal')
  end

  down do
    from(:prompts).where(context: 'internal').update(context: 'prompt')
    from(:favourites).where(context: 'internal').update(context: 'prompt')
  end
end
