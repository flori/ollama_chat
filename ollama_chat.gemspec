# -*- encoding: utf-8 -*-
# stub: ollama_chat 0.0.45 ruby lib

Gem::Specification.new do |s|
  s.name = "ollama_chat".freeze
  s.version = "0.0.45".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Florian Frank".freeze]
  s.date = "1980-01-02"
  s.description = "The app provides a command-line interface (CLI) to an Ollama AI model,\nallowing users to engage in text-based conversations and generate\nhuman-like responses. Users can import data from local files or web pages,\nwhich are then processed through three different modes: fully importing the\ncontent into the conversation context, summarizing the information for\nconcise reference, or storing it in an embedding vector database for later\nretrieval based on the conversation.\n".freeze
  s.email = "flori@ping.de".freeze
  s.executables = ["ollama_chat".freeze, "ollama_chat_send".freeze]
  s.extra_rdoc_files = ["README.md".freeze, "lib/ollama_chat.rb".freeze, "lib/ollama_chat/chat.rb".freeze, "lib/ollama_chat/clipboard.rb".freeze, "lib/ollama_chat/conversation.rb".freeze, "lib/ollama_chat/dialog.rb".freeze, "lib/ollama_chat/document_cache.rb".freeze, "lib/ollama_chat/env_config.rb".freeze, "lib/ollama_chat/follow_chat.rb".freeze, "lib/ollama_chat/history.rb".freeze, "lib/ollama_chat/information.rb".freeze, "lib/ollama_chat/kramdown_ansi.rb".freeze, "lib/ollama_chat/message_format.rb".freeze, "lib/ollama_chat/message_list.rb".freeze, "lib/ollama_chat/message_output.rb".freeze, "lib/ollama_chat/model_handling.rb".freeze, "lib/ollama_chat/ollama_chat_config.rb".freeze, "lib/ollama_chat/parsing.rb".freeze, "lib/ollama_chat/server_socket.rb".freeze, "lib/ollama_chat/source_fetching.rb".freeze, "lib/ollama_chat/switches.rb".freeze, "lib/ollama_chat/think_control.rb".freeze, "lib/ollama_chat/utils.rb".freeze, "lib/ollama_chat/utils/cache_fetcher.rb".freeze, "lib/ollama_chat/utils/chooser.rb".freeze, "lib/ollama_chat/utils/fetcher.rb".freeze, "lib/ollama_chat/utils/file_argument.rb".freeze, "lib/ollama_chat/version.rb".freeze, "lib/ollama_chat/vim.rb".freeze, "lib/ollama_chat/web_searching.rb".freeze]
  s.files = [".utilsrc".freeze, "CHANGES.md".freeze, "Gemfile".freeze, "README.md".freeze, "Rakefile".freeze, "bin/ollama_chat".freeze, "bin/ollama_chat_send".freeze, "config/searxng/settings.yml".freeze, "docker-compose.yml".freeze, "lib/ollama_chat.rb".freeze, "lib/ollama_chat/chat.rb".freeze, "lib/ollama_chat/clipboard.rb".freeze, "lib/ollama_chat/conversation.rb".freeze, "lib/ollama_chat/dialog.rb".freeze, "lib/ollama_chat/document_cache.rb".freeze, "lib/ollama_chat/env_config.rb".freeze, "lib/ollama_chat/follow_chat.rb".freeze, "lib/ollama_chat/history.rb".freeze, "lib/ollama_chat/information.rb".freeze, "lib/ollama_chat/kramdown_ansi.rb".freeze, "lib/ollama_chat/message_format.rb".freeze, "lib/ollama_chat/message_list.rb".freeze, "lib/ollama_chat/message_output.rb".freeze, "lib/ollama_chat/model_handling.rb".freeze, "lib/ollama_chat/ollama_chat_config.rb".freeze, "lib/ollama_chat/ollama_chat_config/default_config.yml".freeze, "lib/ollama_chat/parsing.rb".freeze, "lib/ollama_chat/server_socket.rb".freeze, "lib/ollama_chat/source_fetching.rb".freeze, "lib/ollama_chat/switches.rb".freeze, "lib/ollama_chat/think_control.rb".freeze, "lib/ollama_chat/utils.rb".freeze, "lib/ollama_chat/utils/cache_fetcher.rb".freeze, "lib/ollama_chat/utils/chooser.rb".freeze, "lib/ollama_chat/utils/fetcher.rb".freeze, "lib/ollama_chat/utils/file_argument.rb".freeze, "lib/ollama_chat/version.rb".freeze, "lib/ollama_chat/vim.rb".freeze, "lib/ollama_chat/web_searching.rb".freeze, "ollama_chat.gemspec".freeze, "redis/redis.conf".freeze, "spec/assets/api_show.json".freeze, "spec/assets/api_tags.json".freeze, "spec/assets/api_version.json".freeze, "spec/assets/conversation.json".freeze, "spec/assets/duckduckgo.html".freeze, "spec/assets/example.atom".freeze, "spec/assets/example.csv".freeze, "spec/assets/example.html".freeze, "spec/assets/example.pdf".freeze, "spec/assets/example.ps".freeze, "spec/assets/example.rb".freeze, "spec/assets/example.rss".freeze, "spec/assets/example.xml".freeze, "spec/assets/example_with_quote.html".freeze, "spec/assets/kitten.jpg".freeze, "spec/assets/prompt.txt".freeze, "spec/assets/searxng.json".freeze, "spec/ollama_chat/chat_spec.rb".freeze, "spec/ollama_chat/clipboard_spec.rb".freeze, "spec/ollama_chat/follow_chat_spec.rb".freeze, "spec/ollama_chat/information_spec.rb".freeze, "spec/ollama_chat/kramdown_ansi_spec.rb".freeze, "spec/ollama_chat/message_list_spec.rb".freeze, "spec/ollama_chat/message_output_spec.rb".freeze, "spec/ollama_chat/model_handling_spec.rb".freeze, "spec/ollama_chat/parsing_spec.rb".freeze, "spec/ollama_chat/server_socket_spec.rb".freeze, "spec/ollama_chat/source_fetching_spec.rb".freeze, "spec/ollama_chat/switches_spec.rb".freeze, "spec/ollama_chat/utils/cache_fetcher_spec.rb".freeze, "spec/ollama_chat/utils/fetcher_spec.rb".freeze, "spec/ollama_chat/utils/file_argument_spec.rb".freeze, "spec/ollama_chat/web_searching_spec.rb".freeze, "spec/spec_helper.rb".freeze, "tmp/.keep".freeze]
  s.homepage = "https://github.com/flori/ollama_chat".freeze
  s.licenses = ["MIT".freeze]
  s.rdoc_options = ["--title".freeze, "OllamaChat - A command-line interface (CLI) for interacting with an Ollama AI model.".freeze, "--main".freeze, "README.md".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.2".freeze)
  s.rubygems_version = "4.0.2".freeze
  s.summary = "A command-line interface (CLI) for interacting with an Ollama AI model.".freeze
  s.test_files = ["spec/assets/example.rb".freeze, "spec/ollama_chat/chat_spec.rb".freeze, "spec/ollama_chat/clipboard_spec.rb".freeze, "spec/ollama_chat/follow_chat_spec.rb".freeze, "spec/ollama_chat/information_spec.rb".freeze, "spec/ollama_chat/kramdown_ansi_spec.rb".freeze, "spec/ollama_chat/message_list_spec.rb".freeze, "spec/ollama_chat/message_output_spec.rb".freeze, "spec/ollama_chat/model_handling_spec.rb".freeze, "spec/ollama_chat/parsing_spec.rb".freeze, "spec/ollama_chat/server_socket_spec.rb".freeze, "spec/ollama_chat/source_fetching_spec.rb".freeze, "spec/ollama_chat/switches_spec.rb".freeze, "spec/ollama_chat/utils/cache_fetcher_spec.rb".freeze, "spec/ollama_chat/utils/fetcher_spec.rb".freeze, "spec/ollama_chat/utils/file_argument_spec.rb".freeze, "spec/ollama_chat/web_searching_spec.rb".freeze, "spec/spec_helper.rb".freeze]

  s.specification_version = 4

  s.add_development_dependency(%q<gem_hadar>.freeze, ["~> 2.10".freeze])
  s.add_development_dependency(%q<all_images>.freeze, ["~> 0.6".freeze])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.2".freeze])
  s.add_development_dependency(%q<kramdown>.freeze, ["~> 2.0".freeze])
  s.add_development_dependency(%q<webmock>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<debug>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<simplecov>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<context_spook>.freeze, [">= 0".freeze])
  s.add_runtime_dependency(%q<excon>.freeze, ["~> 1.0".freeze])
  s.add_runtime_dependency(%q<ollama-ruby>.freeze, ["~> 1.18".freeze])
  s.add_runtime_dependency(%q<documentrix>.freeze, ["~> 0.0".freeze, ">= 0.0.2".freeze])
  s.add_runtime_dependency(%q<unix_socks>.freeze, ["~> 0.2".freeze])
  s.add_runtime_dependency(%q<rss>.freeze, ["~> 0.3".freeze])
  s.add_runtime_dependency(%q<term-ansicolor>.freeze, ["~> 1.11".freeze])
  s.add_runtime_dependency(%q<redis>.freeze, ["~> 5.0".freeze])
  s.add_runtime_dependency(%q<mime-types>.freeze, ["~> 3.0".freeze])
  s.add_runtime_dependency(%q<reverse_markdown>.freeze, ["~> 3.0".freeze])
  s.add_runtime_dependency(%q<kramdown-ansi>.freeze, ["~> 0.3".freeze])
  s.add_runtime_dependency(%q<complex_config>.freeze, ["~> 0.22".freeze, ">= 0.22.2".freeze])
  s.add_runtime_dependency(%q<tins>.freeze, ["~> 1.47".freeze])
  s.add_runtime_dependency(%q<search_ui>.freeze, ["~> 0.0".freeze])
  s.add_runtime_dependency(%q<amatch>.freeze, ["~> 0.4".freeze])
  s.add_runtime_dependency(%q<pdf-reader>.freeze, ["~> 2.0".freeze])
  s.add_runtime_dependency(%q<csv>.freeze, ["~> 3.0".freeze])
  s.add_runtime_dependency(%q<const_conf>.freeze, ["~> 0.3".freeze])
end
