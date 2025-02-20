require 'digest/md5'

class OllamaChat::Utils::CacheFetcher
  def initialize(cache)
    @cache = cache
  end

  def get(url, &block)
    block or raise ArgumentError, 'require block argument'
    body         = @cache[key(:body, url)]
    content_type = @cache[key(:content_type, url)]
    content_type = MIME::Types[content_type].first
    if body && content_type
      io = StringIO.new(body)
      io.rewind
      io.extend(OllamaChat::Utils::Fetcher::HeaderExtension)
      io.content_type = content_type
      block.(io)
    end
  end

  def put(url, io)
    io.rewind
    body = io.read
    body.empty? and return
    content_type = io.content_type
    content_type.nil? and return
    @cache.set(key(:body, url), body, ex: io.ex)
    @cache.set(key(:content_type,  url), content_type.to_s, ex: io.ex)
    self
  end

  private

  def key(type, url)
    [ type, Digest::MD5.hexdigest(url) ] * ?-
  end
end
