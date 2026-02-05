# A module that provides location handling functionality for OllamaChat.
#
# The LocationHandling module encapsulates methods for managing location
# information, including generating location data and creating location
# descriptions for use in chat sessions. It integrates with the application's
# configuration to provide contextual location information to language models.
#
# @example Generating location information
#   chat.location_data # => { location_name: "New York", location_decimal_degrees: "40.7128, -74.0060", localtime: "2023-10-15T10:30:00Z", units: "metric" }
#   chat.location_description # => "Current location: New York (40.7128, -74.0060) at 2023-10-15T10:30:00Z in metric units"
#
# @see OllamaChat::Chat
module OllamaChat::LocationHandling
  # Generates a location description string formatted with the current location
  # data.
  #
  # This method creates a formatted string containing location information
  # including name, coordinates, local time, and units, using the configured
  # location prompt template.
  #
  # @return [String] a formatted location description string
  # @see #location_data
  def location_description
    config.prompts.location % location_data
  end

  # Generates a hash containing current location data.
  #
  # This method collects and returns structured location information including
  # the location name, decimal degrees coordinates, local time, and units.
  #
  # @return [Hash] a hash containing location data with keys:
  #   - location_name: The name of the location
  #   - location_decimal_degrees: Comma-separated decimal degrees coordinates
  #   - localtime: Current local time in ISO 8601 format
  #   - units: The unit system (metric, imperial, etc.)
  def location_data
    {
      location_name:            config.location.name,
      location_decimal_degrees: config.location.decimal_degrees * ', ',
      localtime:                Time.now.iso8601,
      units:                    config.location.units,
    }
  end
end
