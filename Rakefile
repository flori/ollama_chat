# vim: set filetype=ruby et sw=2 ts=2:

require 'gem_hadar'

GemHadar do
  name        'ollama_chat'
  module_type :module
  author      'Florian Frank'
  email       'flori@ping.de'
  homepage    "https://github.com/flori/#{name}"
  summary     'A command-line interface (CLI) for interacting with an Ollama AI model.'
  description <<~EOT
    The app provides a command-line interface (CLI) to an Ollama AI model,
    allowing users to engage in text-based conversations and generate
    human-like responses. Users can import data from local files or web pages,
    which are then processed through three different modes: fully importing the
    content into the conversation context, summarizing the information for
    concise reference, or storing it in an embedding vector database for later
    retrieval based on the conversation.
  EOT

  test_dir    'spec'
  ignore      '.*.sw[pon]', 'pkg', 'Gemfile.lock', '.AppleDouble', '.bundle',
    '.yardoc', 'doc', 'tags', 'corpus', 'coverage', '/config/searxng/*',
    '.starscope.db', 'cscope.out'
  package_ignore '.all_images.yml', '.tool-versions', '.gitignore', 'VERSION',
    '.rspec', '.github', '.contexts', '.envrc', '.yardopts'

  readme      'README.md'

  required_ruby_version  '~> 3.2'

  executables << 'ollama_chat' << 'ollama_chat_send'

  github_workflows(
    'static.yml' => {}
  )

  dependency             'excon',                 '~> 1.0'
  dependency             'ollama-ruby',           '~> 1.7'
  dependency             'documentrix',           '~> 0.0', '>= 0.0.2'
  dependency             'unix_socks',            '~> 0.1'
  dependency             'rss',                   '~> 0.3'
  dependency             'term-ansicolor',        '~> 1.11'
  dependency             'redis',                 '~> 5.0'
  dependency             'mime-types',            '~> 3.0'
  dependency             'reverse_markdown',      '~> 3.0'
  dependency             'xdg'
  dependency             'kramdown-ansi',         '~> 0.2'
  dependency             'complex_config',        '~> 0.22', '>= 0.22.2'
  dependency             'tins',                  '~> 1.41'
  dependency             'search_ui',             '~> 0.0'
  dependency             'amatch',                '~> 0.4.1'
  dependency             'pdf-reader',            '~> 2.0'
  dependency             'csv',                   '~> 3.0'
  dependency             'const_conf',            '~> 0.3'
  development_dependency 'all_images',            '~> 0.6'
  development_dependency 'rspec',                 '~> 3.2'
  development_dependency 'kramdown',              '~> 2.0'
  development_dependency 'webmock'
  development_dependency 'debug'
  development_dependency 'simplecov'
  development_dependency 'context_spook'

  licenses << 'MIT'
  
  clobber 'coverage'
end
