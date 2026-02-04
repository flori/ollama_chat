require 'net/http'
require 'uri'
require 'zip'

# A sensor implementation that fetches real-time temperature data from the
# German Weather Service (DWD). This sensor connects to DWD's open data API to
# retrieve the latest air temperature measurements for a specified weather
# station.
#
# The sensor expects DWD data files in ZIP format containing CSV data with the
# following structure:
# - Files are named like: 10minutenwerte_TU_00433_now.zip
# - Data is stored in CSV format with semicolon separators
# - Temperature values are in the TT_10 column (in Celsius)
# - Timestamps are in MESS_DATUM column (format: YYYYMMDDHHMM)
#
# Example usage:
#   sensor = DWDSensor.new(sensor_id: 'station_1', station_id: '00433')
#   temperature = sensor.measure
class DWDSensor
  DEFAULT_URL_TEMPLATE = "https://opendata.dwd.de/climate_environment/CDC/observations_germany/climate/10_minutes/air_temperature/now/10minutenwerte_TU_%{station_id}_now.zip" # Template for the download URL

  # Initializes a new sensor reader instance with the specified parameters.
  #
  # @param sensor_id [ String ] the unique identifier for the sensor
  # @param station_id [ String ] the unique identifier for the weather station
  # @param url_template [ String ] the URL template for fetching sensor data
  # @param logger [ Logger ] the logger instance to use for logging messages
  def initialize(sensor_id:, station_id:, url_template: DEFAULT_URL_TEMPLATE, logger: Logger.new($stderr))
    @sensor_id     = sensor_id
    @station_id    = station_id
    @url_template  = url_template
    @last_modified = nil
    @logger        = logger
  end

  # The sensor_id method provides read-only access to the identifier of the
  # sensor.
  #
  # @attr_reader [ String, Integer ] the unique identifier assigned to the sensor
  # instance
  attr_reader :sensor_id

  # The measure method reads temperature data from a sensor and returns
  # timestamped measurements.
  #
  # @return [ Array<Time, Float>, nil ] an array containing the timestamp and temperature reading,
  #                                       or nil if no valid temperature could be read
  # @return [ nil ] if no temperature reading was available
  def measure
    @logger.info "Starting to read temperature from #{self.class} #{@sensor_id}…"
    time, temp = read_temperature
    if time && temp
      @logger.info "Read temperature from #{self.class} #{@sensor_id} at #{time.iso8601}: #{temp}℃ "
      [ time, temp ]
    else
      nil
    end
  end

  private

  # Reads the temperature data for the station, skipping the fetch if data is
  # still current.
  #
  # This method first checks if the data fetching should be skipped based on
  # the last modified timestamp comparison. If skipping is not appropriate, it
  # proceeds to fetch the latest temperature data from DWD API.
  #
  # @return [nil] if the data fetching was skipped or failed
  # @return [Array<Time, Float>] the result of the temperature fetching operation
  #   if successful
  def read_temperature
    if skip_fetching?
      @logger.info "Data for station #{@station_id} still current from #{@last_modified.iso8601} => Skip fetching."
      return
    end
    fetch_latest_temperature_from_dwd
  rescue => e
    @logger.error "Failed to fetch DWD data for station #{@station_id} => #{e.class}: #{e}"
    nil
  end

  # Returns a URI object constructed from the URL template and station ID.
  #
  # @return [URI] a URI object created by interpolating the station ID into the URL template
  def uri
    URI(@url_template % { station_id: @station_id })
  end

  # Determines whether fetching should be skipped based on modification time
  # comparisons.
  #
  # @return [ Boolean ] true if the resource has not been modified since last
  #                     fetch, false otherwise
  # @return [ Boolean ] false if no previous modification time is available
  def skip_fetching?
    @last_modified or return false
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
      http.head(uri.path)
    end
    last_modified = Time.parse(response['Last-Modified'])
    if last_modified > @last_modified
      @last_modified = nil
      false
    else
      true
    end
  end


  # Fetches the latest temperature data from DWD API for the configured
  # station.
  #
  # This method performs an HTTP GET request to the DWD open data API endpoint,
  # retrieves the ZIP file containing weather data, and processes it to extract
  # the most recent temperature reading. It handles various HTTP status codes
  # and network errors gracefully.
  #
  # @return [Array<Time, Float>, nil] An array containing the timestamp and
  # temperature value of the measurement, or nil if the fetch or processing
  # fails
  def fetch_latest_temperature_from_dwd
    @logger.debug "Fetching DWD data from: #{uri}"
    response = Net::HTTP.get_response(uri)
    if response.code == '200'
      @logger.info "Successfully fetched data for station #{@station_id}"

      result = extract_from_zip(response.body)
      @last_modified = Time.parse(response['Last-Modified'])
      result
    elsif response.code == '404'
      @logger.error "File not found for station #{@station_id}: #{uri}"
      nil
    else
      @logger.error "HTTP Error #{response.code}: #{response.message}"
      nil
    end
  rescue => e
    @logger.error "Network error fetching DWD data => #{e.class}: #{e}"
    nil
  end

  # Extracts temperature data from a ZIP file containing DWD CSV data.
  #
  # This method takes raw ZIP file data, extracts the first entry (expected to
  # be the CSV weather data), and processes it to return the latest temperature
  # reading. The ZIP file is expected to contain CSV data with semicolon
  # separators.
  #
  # @param zip_body [String] The raw binary content of the ZIP file
  # @return [Array<Time, Float>, nil] An array containing the timestamp and temperature value,
  #   or nil if extraction or parsing fails
  def extract_from_zip(zip_body)
    # Create StringIO from response body
    zip_data = StringIO.new(zip_body)

    # Extract the first entry from ZIP file (should be the CSV data)
    Zip::File.open_buffer(zip_data) do |zip_file|
      entry = zip_file.first
      if entry
        content = entry.get_input_stream.read
        @logger.debug "Extracted #{content.length} bytes from ZIP"
        return parse_dwd_data(content)
      else
        @logger.error "No entries found in ZIP file for station #{@station_id}"
        nil
      end
    end
  rescue => e
    @logger.error "Error extracting from ZIP: #{e}"
    nil
  end

  # Parses DWD CSV data to extract the latest temperature reading for a weather
  # station.
  #
  # @param data [String] The raw CSV data string from DWD containing weather measurements
  # @return [Array<Time, Float>, nil] An array containing the timestamp and temperature value,
  #   or nil if no valid temperature data is found or if there are no data entries
  def parse_dwd_data(data)
    # Parse CSV data from DWD
    csv_data = CSV.parse(data, headers: true, col_sep: ?;)

    # Find the latest entry (most recent timestamp)
    latest_entry, time = csv_data.
      map { |row| [ row, Time.strptime(row['MESS_DATUM'], '%Y%m%d%H%M') ] }.
      max_by(&:last)

    if latest_entry
      temp = latest_entry['TT_10']
      if temp && temp != '9999'  # 9999 indicates missing data
        [ time, temp.to_f ]
      else
        @logger.warn "No valid temperature data found for station #{@station_id}"
        nil
      end
    else
      @logger.warn "No data entries found for station #{@station_id}"
      nil
    end
  end
end
