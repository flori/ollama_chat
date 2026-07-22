# Renames the 'system_prompt' context to 'system' in both prompts and favourites
# tables to align with the unified prompt management structure.
Sequel.migration do
   up do
    from(:prompts).where(context: 'system_prompt').update(context: 'system')
    from(:favourites).where(context: 'system_prompt').update(context: 'system')
  end

  down do
    from(:prompts).where(context: 'system').update(context: 'system_prompt')
    from(:favourites).where(context: 'system').update(context: 'system_prompt')
  end
end
