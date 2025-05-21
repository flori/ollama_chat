module OllamaChat::Information
  extend Tins::Concern

  included do
    include UserAgent
    extend UserAgent
  end

  module UserAgent
    def progname
      'ollama_chat'
    end

    def user_agent
      [ progname, OllamaChat::VERSION ] * ?/
    end
  end

  def collection_stats
    STDOUT.puts <<~EOT
      Current Collection
        Name: #{bold{@documents.collection}}
        #Embeddings: #{@documents.size}
        #Tags: #{@documents.tags.size}
        Tags: #{@documents.tags}
    EOT
    nil
  end

  def info
    STDOUT.puts "Running ollama_chat version: #{bold(OllamaChat::VERSION)}"
    STDOUT.puts "Connected to ollama server version: #{bold(server_version)}"
    STDOUT.puts "Current model is #{bold{@model}}."
    if @model_options.present?
      STDOUT.puts "  Options: #{JSON.pretty_generate(@model_options).gsub(/(?<!\A)^/, '  ')}"
    end
    @embedding.show
    if @embedding.on?
      STDOUT.puts "Embedding model is #{bold{@embedding_model}}"
      if @embedding_model_options.present?
        STDOUT.puts "  Options: #{JSON.pretty_generate(@embedding_model_options).gsub(/(?<!\A)^/, '  ')}"
      end
      STDOUT.puts "Text splitter is #{bold{config.embedding.splitter.name}}."
      collection_stats
    end
    STDOUT.puts "Documents database cache is #{@documents.nil? ? 'n/a' : bold{@documents.cache.class}}"
    markdown.show
    stream.show
    location.show
    STDOUT.puts "Document policy for references in user text: #{bold{@document_policy}}"
    STDOUT.puts "Currently selected search engine is #{bold(search_engine)}."
    if @voice.on?
      STDOUT.puts "Using voice #{bold{@current_voice}} to speak."
    end
    @messages.show_system_prompt
    nil
  end

  def display_chat_help
    STDOUT.puts <<~EOT
      /copy                           to copy last response to clipboard
      /paste                          to paste content
      /markdown                       toggle markdown output
      /stream                         toggle stream output
      /location                       toggle location submission
      /voice [change]                 toggle voice output or change the voice
      /list [n]                       list the last n / all conversation exchanges
      /clear [messages|links|history] clear the all messages, links, or the chat history (defaults to messages)
      /clobber                        clear the conversation, links, and collection
      /drop [n]                       drop the last n exchanges, defaults to 1
      /model                          change the model
      /system                         change system prompt (clears conversation)
      /regenerate                     the last answer message
      /collection [clear|change]      change (default) collection or clear
      /info                           show information for current session
      /config                         output current configuration (#{@ollama_chat_config.filename.to_s.inspect})
      /document_policy                pick a scan policy for document references
      /import source                  import the source's content
      /summarize [n] source           summarize the source's content in n words
      /embedding                      toggle embedding paused or not
      /embed source                   embed the source's content
      /web [n] query                  query web search & return n or 1 results
      /links( clear)                  display (or clear) links used in the chat
      /save filename                  store conversation messages
      /load filename                  load conversation messages
      /quit                           to quit
      /help                           to view this help
    EOT
    nil
  end

  def usage
    STDOUT.puts <<~EOT
      Usage: #{progname} [OPTIONS]

        -f CONFIG      config file to read
        -u URL         the ollama base url, OLLAMA_URL
        -m MODEL       the ollama model to chat with, OLLAMA_CHAT_MODEL
        -s SYSTEM      the system prompt to use as a file, OLLAMA_CHAT_SYSTEM
        -c CHAT        a saved chat conversation to load
        -C COLLECTION  name of the collection used in this conversation
        -D DOCUMENT    load document and add to embeddings collection (multiple)
        -M             use (empty) MemoryCache for this chat session
        -E             disable embeddings for this chat session
        -V             display the current version number and quit
        -h             this help

    EOT
    0
  end

  def version
    STDOUT.puts "%s %s" % [ progname, OllamaChat::VERSION ]
    0
  end

  def server_version
    @server_version ||= ollama.version.version
  end
end
