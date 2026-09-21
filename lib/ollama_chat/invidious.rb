# Fetches YouTube video metadata and transcripts through an Invidious
# companion instance.
#
# Only activates when OC::OLLAMA::CHAT::INVIDIOUS::URL is set.
# Non-YouTube URLs and unconfigured environments return nil.
#
# @example Fetching video info for a YouTube watch URL
#   text = OllamaChat::Invidious.fetch_video_info(
#     'https://www.youtube.com/watch?v=Fypm8CDHwc8', chat:
#   )
module OllamaChat
  class Invidious
    YOUTUBE_URLS = %r{
      \A
      (?:https?://)?
      (?:www\.|m\.|music\.)?
      (?:youtube\.com/(?:watch\?v=|embed/|shorts/)|youtu\.be/)
      ([\w-]{11})
    }x

    class << self
      # Fetches video metadata (title, channel, description, duration)
      # and, when available, a clean transcript via the Invidious
      # companion player endpoint.
      #
      # Steps:
      #   1. POST /companion/youtubei/v1/player -> videoDetails +
      #      captionTracks (single response)
      #   2. Match languageCode against configured priority regexes
      #   3. GET the matched track's baseUrl → timedtext XML
      #   4. Extract <text> elements via Nokogiri → plain text
      #
      # @param url [String] the YouTube source URL
      # @param chat [OllamaChat::Chat] the chat instance (for HTTP
      #   middleware)
      # @return [StringIO, nil] video info + transcript as a text IO,
      #   or nil if not a YouTube URL, Invidious not configured, or
      #   video details unavailable
      def fetch_video_info(url, chat:)
        invidious_url = OC::OLLAMA::CHAT::INVIDIOUS::URL? or return
        video_id = url[YOUTUBE_URLS, 1] or return

        base = invidious_url.to_s
        key  = OC::OLLAMA::CHAT::INVIDIOUS::COMPANION_KEY

        # Step 1: POST /companion/youtubei/v1/player
        player_response = nil
        chat.request_url_response(
          :post, "#{base}/companion/youtubei/v1/player",
          body:        JSON.dump('videoId' => video_id),
          headers:     {
            'Content-Type'  => 'application/json',
            'Authorization' => "Bearer #{key}",
          },
          expects:     200,
          middlewares: OllamaChat::Utils::Fetcher.middlewares,
        ) do |response|
          player_response = JSON.parse(response.body)
        rescue JSON::ParserError => e
          chat.log(:error, e, data: { url: })
        end
        return unless player_response

        details = player_response['videoDetails']
        return unless details

        header = format_details(details)

        # Steps 2-4: pick track, fetch VTT, strip (best effort)
        tracks = player_response.dig(
          'captions', 'playerCaptionsTracklistRenderer', 'captionTracks'
        )
        transcript = fetch_transcript(tracks, chat)

        text = transcript ? header + transcript
                           : header + "No captions available.\n"
        OllamaChat::Utils::Fetcher::ResponseMetadata.as_text(text)
      end

      private

      # Selects the best caption track by language priority, fetches
      # its timedtext XML from the YouTube baseUrl, and extracts the
      # transcript text via Nokogiri.
      #
      # @param tracks [Array<Hash>, nil] captionTracks from the
      #   player response
      # @param chat [OllamaChat::Chat] the chat instance
      # @return [String, nil] cleaned transcript or nil
      def fetch_transcript(tracks, chat)
        langs = OC::OLLAMA::CHAT::INVIDIOUS::CAPTION_LANGUAGES
        track = pick_track(tracks, langs) or return nil

        xml = nil
        chat.get_url(
          track['baseUrl'], remember: false
        ) { |tmp| xml = tmp.read }

        xml && strip_xml(xml)
      end

      # Iterates the priority list of language regexes and returns the
      # first track whose languageCode matches any pattern.
      #
      # @param tracks [Array<Hash>, nil] caption entries from the API
      # @param langs [Array<Regexp>] priority-ordered regexes
      # @return [Hash, nil] the selected track entry
      def pick_track(tracks, langs)
        return nil unless tracks&.any?

        langs.each do |pattern|
          track = tracks.find { |t| t['languageCode'] =~ pattern }
          return track if track
        end

        nil
      end

      # Extracts transcript text from YouTube timedtext XML using
      # Nokogiri. Word-level <text> elements are joined into a
      # readable paragraph.
      #
      # @param xml [String] raw timedtext XML content
      # @return [String, nil] cleaned transcript or nil
      def strip_xml(xml)
        doc  = Nokogiri::XML(xml)
        text = doc.xpath('//text')
          .map { |n| n.text.strip }
          .reject(&:blank?)
          .join(' ')
          .strip
        text.full? { Nokogiri::HTML.fragment(_1).text }
      end

      # Formats videoDetails into a markdown header.
      #
      # @param details [Hash] videoDetails from the player API
      # @return [String] formatted header with trailing separator
      def format_details(details)
        <<~HDR.chomp
          # #{details['title']}

          **Channel:** #{details['author']}
          **Duration:** #{format_duration(details['lengthSeconds'].to_i)}

          #{details['shortDescription'].to_s.strip}

          ---

        HDR
      end

      # Formats a duration in seconds as a human-readable string.
      #
      # @param seconds [Integer] duration in seconds
      # @return [String] e.g. "03:25:45"
      def format_duration(seconds)
        Tins::Duration.new(seconds).to_s
      end
    end
  end
end
