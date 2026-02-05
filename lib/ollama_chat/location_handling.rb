module OllamaChat::LocationHandling
  def location_description
    config.prompts.location % location_data
  end

  def location_data
    {
      location_name:            config.location.name,
      location_decimal_degrees: config.location.decimal_degrees * ', ',
      localtime:                Time.now.iso8601,
      units:                    config.location.units,
    }
  end
end
