require 'uri'

# Redacts credentials from URLs for safe, user-facing display.
#
# Whenever a URL that may carry a password (e.g.
# `http://user:secret@host`) is about to be printed to the terminal or
# echoed back to the model, run it through {#redact_password} so the
# secret is masked as `***`.
#
# @example
#   OllamaChat::Utils::Redact.redact_password('http://u:secret@example.com')
#   # => "http://u:***@example.com"
#
# The module can also be +include+d to gain {#redact_password} as a
# private helper on the host class.
module OllamaChat::Utils::Redact
  module_function

  # Returns the URL as a string with its password component replaced by
  # `***`. Accepts a +URI+ or a plain +String+ (parsed on the fly). The
  # original object is never mutated: a duplicate is redacted and the
  # result returned as a string. URLs without a password are returned
  # unchanged.
  #
  # @param url [URI, String] the URL whose password should be hidden
  # @return [String] the URL with its password redacted
  def redact_password(url)
    uri = url.is_a?(String) ? URI.parse(url) : url.dup
    uri.password = '***' if uri.password
    uri.to_s
  end
end
