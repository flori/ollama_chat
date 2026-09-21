require 'securerandom'

# Standalone ASR (Speech-to-Text) transcription client for audio.cpp.
#
# Transcribes audio or video sources by uploading them as multipart
# form-data to the audio.cpp `/v1/audio/transcriptions` endpoint.
# Video sources are first converted to 16 kHz mono WAV via ffmpeg.
#
# @example Transcribing a WAV source
#   text = OllamaChat::ASR.transcribe(source_io)
#
# @example Transcribing an MP4 video (ffmpeg extraction)
#   text = OllamaChat::ASR.transcribe(source_io)
module OllamaChat
  class ASR
    class << self
      # Transcribes audio/video content via the audio.cpp ASR endpoint.
      #
      # @param source_io [IO] the audio/video source stream
      #   (must respond to #content_type and be seekable)
      # @param language [String, nil] optional language hint
      #   (e.g. "en", "de") passed as the `language` form field
      #
      # @return [String, nil] the transcribed text, or nil on failure
      def transcribe(source_io, language: nil, **excon_opts)
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
          system(cmd, out: File::NULL, err: File::NULL)
          unless File.size(wav.path) > 0
            STDERR.puts 'ASR: ffmpeg produced no output.'
            return
          end

          url       = "#{asr_url}/v1/audio/transcriptions"
          excon     = Excon.new(url, **excon_opts)
          form_data = multipart_form_data(wav.path, model: asr_model, language:)
          response  = excon.post(form_data)
          JSON.parse(response.body)['text']
        ensure
          input.close!
          wav&.close!
        end
      rescue => e
        STDERR.puts "ASR transcription failed: #{e.message}"
        nil
      end

      private

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

        rest.symbolize_keys_recursive.compact | {
          :headers => { 'Content-Type' => %{multipart/form-data; boundary="#{boundary}"} },
          :body    => body
        }
      end
    end
  end
end
