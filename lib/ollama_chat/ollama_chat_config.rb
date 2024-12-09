class OllamaChat::OllamaChatConfig
  include ComplexConfig
  include FileUtils

  DEFAULT_CONFIG = <<~EOT
      ---
      url: <%= ENV['OLLAMA_URL'] || 'http://%s' % ENV.fetch('OLLAMA_HOST') %>
      proxy: null # http://localhost:8080
      model:
        name: <%= ENV.fetch('OLLAMA_CHAT_MODEL', 'llama3.1') %>
        options:
          num_ctx: 8192
      location:
        enabled: false
        name: Berlin
        decimal_degrees: [ 52.514127, 13.475211 ]
        units: SI (International System of Units) # or USCS (United States Customary System)
      prompts:
        embed: "This source was now embedded: %{source}"
        summarize: |
          Generate an abstract summary of the content in this document using
          %{words} words:

          %{source_content}
        web: |
          Answer the the query %{query} using these sources and summaries:

          %{results}
      system_prompts:
        default: <%= ENV.fetch('OLLAMA_CHAT_SYSTEM', 'null') %>
      voice:
        enabled: false
        default: Samantha
        list: <%= `say -v ? 2>/dev/null`.lines.map { _1[/^(.+?)\s+[a-z]{2}_[a-zA-Z0-9]{2,}/, 1] }.uniq.sort.to_s.force_encoding('ASCII-8BIT') %>
      markdown: true
      stream: true
      document_policy: importing
      embedding:
        enabled: true
        model:
          name: mxbai-embed-large
          embedding_length: 1024
          options: {}
          # Retrieval prompt template:
          prompt: 'Represent this sentence for searching relevant passages: %s'
        batch_size: 10
        database_filename: null # ':memory:'
        collection: <%= ENV['OLLAMA_CHAT_COLLECTION'] %>
        found_texts_size: 4096
        found_texts_count: 10
        splitter:
          name: RecursiveCharacter
          chunk_size: 1024
      cache: Documentrix::Documents::SQLiteCache
      redis:
        documents:
          url: <%= ENV.fetch('REDIS_URL', 'null') %>
        expiring:
          url: <%= ENV.fetch('REDIS_EXPIRING_URL', 'null') %>
          ex: 86400
      debug: <%= ENV['OLLAMA_CHAT_DEBUG'].to_i == 1 ? true : false %>
      ssl_no_verify: []
      copy: pbcopy
  EOT

  def initialize(filename = nil)
    @filename = filename || default_path
    unless File.directory?(cache_dir_path)
      mkdir_p cache_dir_path.to_s
    end
    @config = Provider.config(@filename, '⚙️')
    retried = false
  rescue ConfigurationFileMissing
    if @filename == default_path && !retried
      retried = true
      mkdir_p config_dir_path.to_s
      File.secure_write(default_path, DEFAULT_CONFIG)
      retry
    else
      raise
    end
  end

  attr_reader :filename

  attr_reader :config

  def default_path
    config_dir_path + 'config.yml'
  end

  def config_dir_path
    XDG.new.config_home + 'ollama_chat'
  end

  def cache_dir_path
    XDG.new.cache_home + 'ollama_chat'
  end

  def database_path
    cache_dir_path + 'documents.db'
  end
end
