require 'securerandom'

# Standalone ASR (Speech-to-Text) transcription client for audio.cpp.
#
# Transcribes audio or video sources by uploading them as multipart
# form-data to the audio.cpp `/v1/audio/transcriptions` endpoint.
# Video sources are first converted to 16 kHz mono WAV via ffmpeg.
#
# @example Transcribing a WAV source
#   text = OllamaChat::ASR.transcribe(source_io, chat:)
#
# @example Transcribing an MP4 video (ffmpeg extraction)
#   text = OllamaChat::ASR.transcribe(source_io, chat:)
module OllamaChat
  class ASR
    class << self
      # Transcribes audio/video content via the audio.cpp ASR endpoint.
      #
      # @param source_io [IO] the audio/video source stream
      #   (must respond to #content_type and be seekable)
      # @param language [String, nil] optional language hint
      #   (e.g. "en", "de") passed as the `language` form field
      # @param chat [OllamaChat::Chat] the chat instance (for HTTP middleware)
      #
      # @return [String, nil] the transcribed text, or nil on failure
      def transcribe(source_io, chat:, language: nil)
        asr_url   = OC::OLLAMA::CHAT::ASR::URL
        asr_model = OC::OLLAMA::CHAT::ASR::MODEL
        input = Tempfile.new(['asr_in'])
        wav   = Tempfile.new(['asr', '.wav'])
        begin
          IO.copy_stream(source_io, input)
          input.flush

          cmd = OC::OLLAMA::CHAT::ASR::CONVERT_COMMAND % {
            input: input.path, output: wav.path
          }
          executable = Shellwords.split(cmd).first
          result     = system(cmd, out: File::NULL, err: File::NULL)
          if result.nil?
            STDERR.puts "ASR: #{executable} not found in PATH."
            return
          end
          unless File.size(wav.path) > 0
            STDERR.puts "ASR: #{executable} produced no output."
            return
          end

          url       = "#{asr_url}/v1/audio/transcriptions"
          form_data = multipart_form_data(wav.path, model: asr_model, language:)
          chat.request_url_response(:post, url, **form_data) do |response|
            return JSON.parse(response.body)['text']
          end
        ensure
          input.close!
          wav&.close!
        end
      rescue JSON::ParserError, Excon::Error => e
        if response = e.ask_and_send(:response)
          status = response.status
          result = JSON.parse(response.body) rescue nil
        end
        chat.log(:error, e, data: { status:, result: })
        STDERR.puts "ASR transcription failed: #{e.message}"
        nil
      end

      private

      # Builds a multipart/form-data request body for the ASR endpoint.
      #
      # Constructs the wire format manually (boundary, text field parts,
      # file part) so the result can be splatted directly into
      # {HTTPHandling#request_url_response}.
      #
      # @param file_path [String] path to the WAV file to upload
      # @param rest [Hash] additional form fields (e.g. `model:`,
      #   `language:`); `nil` values are omitted via `compact`
      #
      # @return [Hash] Excon-compatible options with `:headers`
      #   (Content-Type including the generated boundary), `:expects`
      #   (200), and `:body` (the assembled multipart string)
      def multipart_form_data(file_path, **rest)
        path     = Pathname.new(file_path)
        body     = ''
        boundary = SecureRandom.hex(8)

        rest.compact.each do |field_name, field_value|
          body << "--#{boundary}\r\n"
          body << "Content-Disposition: form-data; name=\"#{field_name}\"\r\n\r\n"
          body << "#{field_value}\r\n"
        end

        body << "--#{boundary}" << Excon::CR_NL
        body << %{Content-Disposition: form-data; name="file"; filename="#{path.basename}"} << Excon::CR_NL
        body << 'Content-Type: audio/wav' << Excon::CR_NL
        body << Excon::CR_NL
        body << path.binread
        body << Excon::CR_NL
        body << "--#{boundary}--" << Excon::CR_NL

        {
          headers: { 'Content-Type' => %{multipart/form-data; boundary="#{boundary}"} },
          expects: 200,
          body:    ,
        }
      end
    end
  end
end
