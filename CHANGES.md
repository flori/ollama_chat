# Changes

## 2025-10-31 v0.0.37

- Refactored system prompt selection logic to use `case`/`when` statement
  instead of `if`/`elsif` for improved readability
- Maintained same functionality for regex pattern matching with `/\A\?(.+)\z/`
  pattern
- Handled special case with `?` argument to match any character with `/./` regex
- Updated `amatch` dependency version constraint from `~> 0.4.1` to `~> 0.4` in
  `Rakefile` and `ollama_chat.gemspec`
- Updated `rubygems` version requirement from **3.6.9** to **3.7.2** in
  `ollama_chat.gemspec`

## 2025-10-11 v0.0.36

- Added `openssl-dev` package to apk packages in Dockerfile
- Replaced explicit `_1` parameter syntax with implicit `_1` syntax for
  compatibility with older Ruby versions
- Removed `require 'xdg'` statement from `chat.rb`
- Removed `xdg` gem dependency and implemented direct XDG directory usage
- Added documentation link to README with a link to the GitHub.io documentation
  site
- Introduced GitHub Actions workflow for static content deployment to GitHub
  Pages
- Updated `gem_hadar` development dependency to version **2.8**
- Reordered menu options in dialog prompts to place `[EXIT]` first
- Corrected YARD documentation guidelines for `initialize` methods
- Updated documentation comments with consistent formatting
- Updated Redis (ValKey) image version from **8.1.1** to **8.1.3**
- Removed deprecated `REDIS_EXPRING_URL` environment variable from `.envrc`

## 2025-09-18 v0.0.35

- Replaced ad-hoc ENV handling with `const_conf` gem for structured
  configuration management
- Bumped required Ruby version from **3.1** to **3.2**
- Added `const_conf (~> 0.3)` as a runtime dependency
- Introduced `OllamaChat::EnvConfig` module to centralize environment variables
- Updated `OllamaChat::Chat`, `OllamaChat::FollowChat`, and related classes to
  use the new configuration system
- Replaced direct ENV access with `EnvConfig::OLLAMA::URL`,
  `EnvConfig::PAGER?`, etc.
- Refactored default configuration values in YAML files to use `const_conf`
  constants
- Removed legacy debug flag handling and simplified `debug` method
  implementation
- Updated test suite to use `const_conf_as` helper and removed old ENV stubbing
  logic
- Adjusted gemspec to include new files and dependencies, updated required Ruby
  version
- Updated regex pattern to match only escaped spaces in file paths

## 2025-09-17 v0.0.34

- Modified `-d` flag semantics to use working directory instead of runtime
  directory for socket path derivation
- Updated `send_to_server_socket` and `create_socket_server` methods to accept
  `working_dir` parameter
- Changed argument parsing in `ollama_chat_send` binary to utilize
  `working_dir` instead of `runtime_dir`
- Updated documentation and help text to reflect new `-d` option semantics
- Added tests covering new `working_dir` functionality with default fallback to
  current directory
- Maintained backward compatibility by preserving existing `runtime_dir`
  behavior when specified
- Modified method signatures to support both old and new parameter styles

## 2025-09-15 v0.0.33

- Enhanced `CONTENT_REGEXP` to support escaped spaces in file paths using
  `(?:\\\ |\\|[^\\ ]+)`
- Modified `SourceFetching` module to properly unescape spaces with `gsub('\ ',
  ' ')`
- Added new test case `can parse file path with escaped spaces` to verify
  functionality

## 2025-09-15 v0.0.32

- Fixed file path parsing for escaped spaces and URI handling
  - Updated regex pattern for relative paths to better handle `\ ` escaped spaces
  - Added explicit unescaping of spaces in test case for `./spec/assets/file\ with\ spaces.html`

## 2025-09-15 v0.0.31

- Added new test asset file `"spec/assets/example with \".html"` as
  `spec/assets/example_with_quote.html`
- Enhanced parsing tests in `spec/ollama_chat/parsing_spec.rb` to support file
  URLs with spaces and quotes
- Added cleanup code using `FileUtils.rm_f` in test cases to remove temporary
  files
- Modified test method names to reflect support for spaces and quotes in file
  paths
- Added `ghostscript` package to the Dockerfile dependencies
- Added `fail_fast: true` to the script configuration
- Added a check for `pbcopy` command in clipboard spec
- Wrapped SimpleCov require in begin/rescue block to handle LoadError
- Set default `OLLAMA_HOST` environment variable to 'localhost:11434' in spec
  helper
- Added `CONTENT_REGEXP` for unified parsing of URLs, tags, and file references
- Updated `parse_content` method to use new regex and support quoted file paths
- Introduced `check_exist:` option in `fetch_source` to validate file existence
- Extracted file reading logic into new helper method
  `fetch_source_as_filename`
- Enhanced handling of file URLs with spaces and special characters
- Added comprehensive tests for parsing file paths with spaces, quotes, and
  encoding
- Supported `file://` URI decoding using `URI.decode_www_form_component`
- Refactored `fetch_source` to better handle relative, absolute, and tilde
  paths
- Updated spec files to use `Pathname` and improved assertions for file content
- Updated `gem_hadar` development dependency version from **2.3** to **2.6**

## 2025-09-11 v0.0.30

- Changed `config.prompts.web_import` to `config.prompts.web_summarize` in default branch
- Updated method calls from `import(url).full?` to `summarize(url).full?` in summarizing branch
- Updated method calls from `summarize(url).full?` to `import(url).full?` in default branch
- Added `ask_and_send_or_self(:read)` call within the block for both branches
- Added `ruby:3.1-alpine` image configuration to CI pipeline

## 2025-09-08 v0.0.29

- Refactored conversation persistence into a dedicated
  `OllamaChat::Conversation` module
- Added automatic backup saving in the `fix_config` method using
  **backup.json**
- Simplified `/save` and `/load` commands to delegate to module methods
- Introduced document processing policies for web search results with three
  modes: **embedding**, **summarizing**, and **importing**
- Added `@document_policy` configuration to control result processing mode
- Updated `/web` command help text and added new prompt templates for summarization and importing modes
- Modified conditional logic from `@embedding.on?` to `@document_policy == 'embedding' && @embedding.on?`

## 2025-09-08 v0.0.28

- Replaced `server_socket_runtime_dir` config option with
  `working_dir_dependent_socket`
- Used `Digest::MD5` to generate unique socket names based on working directory
- Socket names now follow format `ollama_chat-<hash>.sock` instead of fixed
  name
- Updated `unix_socks` dependency version constraint from >= 0.0.1 to ~> 0.1
- Added new `.utilsrc` configuration file for code indexing and search
  utilities
- Added return type documentation to `CacheFetcher#get` method

## 2025-09-05 v0.0.27

- Enhanced cache hit notifications to properly handle content type with
  fallback to 'unknown'
- Modified `OllamaChat::Utils::CacheFetcher` to return `io` for proper content
  type propagation

## 2025-08-27 v0.0.26

- Enhanced `/last` command to support numeric argument, allowing users to
  specify the number of messages to display
- Configured tests to protect environment variables by using `protect_env:
  true` option and direct `ENV` manipulation
- Refactored spec helper with modularized `AssetHelpers`, `StubOllamaServer`,
  and `ProtectEnvVars` modules for better organization
- Improved code clarity and added comprehensive documentation across multiple
  modules including `OllamaChat`, `Chat`, `MessageList`, and others
- Added detailed class-level documentation for `OllamaChatConfig` with examples
- Included documentation for the `Parsing`, `Vim`, `MessageFormat`,
  `KramdownANSI`, `Information`, `UserAgent`, and `History` modules
- Improved cache hit message formatting and wording for better user experience

## 2025-08-18 v0.0.25

- Integrated `context_spook` gem as development dependency
- Added new context files: `.contexts/full.rb`, `.contexts/info.rb`, and
  `.contexts/lib.rb`
- Updated `ollama-ruby` dependency version constraint from `~> 1.2` to `~> 1.6`
- Bumped **tins** dependency from ~> **1.34** to ~> **1.41**
- Refactored `web` method in `chat.rb` to conditionally handle embeddings
- Split web prompt templates into `web_embed` and `web_import`
- Moved cache check message to display before cache retrieval
- Fixed `show_last` behavior for empty lists with comprehensive tests
- Added nil check to `kramdown_ansi_parse` method to prevent `NoMethodError`
- Added documentation comments to `OllamaChat::Clipboard`,
  `OllamaChat::Dialog`, `OllamaChat::Utils::Chooser`, and
  `OllamaChat::Utils::FileArgument` modules
- Added new command line option `-d DIR` to specify runtime directory for
  socket file
- Updated `OllamaChat::ServerSocket.send_to_server_socket` method to accept
  `runtime_dir` parameter
- Modified `create_socket_server` method to use provided `runtime_dir` when
  creating Unix socket server
- Updated help text to document the new `-d` option
- Added separate context for `runtime_dir` parameter testing in spec

## 2025-08-17 v0.0.24

- Updated `kramdown-ansi` dependency version constraint from **0.0** to **0.1**
- Modified both Rakefile and `ollama_chat.gemspec` files to reflect new version
  constraint for `kramdown-ansi`

## 2025-08-17 v0.0.23

- Added `OllamaChat::KramdownANSI` module with `configure_kramdown_ansi_styles`
  and `kramdown_ansi_parse` methods for consistent Markdown formatting
- Replaced direct calls to `Kramdown::ANSI.parse` with
  `@chat.kramdown_ansi_parse` in `FollowChat` and `MessageList`
- Integrated `OllamaChat::KramdownANSI` module into `OllamaChat::Chat` class
- Configured `@kramdown_ansi_styles` during chat initialization
- Added support for environment variables `KRAMDOWN_ANSI_OLLAMA_CHAT_STYLES`
  and `KRAMDOWN_ANSI_STYLES` for styling configuration
- Updated tests to mock `kramdown_ansi_parse` instead of direct
  `Kramdown::ANSI.parse`
- Documented environment variables for customizing Markdown formatting with
  example JSON format
- Added `lib/ollama_chat/kramdown_ansi.rb` to `extra_rdoc_files` and `files`
  list in gemspec
- Escaped dot in regex pattern in `parsing_spec.rb` for proper image file
  matching
- Implemented `File.expand_path` to resolve `~` shortcuts before existence
  check in parsing module
- Added error handling for malformed paths by rescuing `ArgumentError`
  exceptions
- Skipped invalid file paths during processing loop using `next` statement
- Maintained backward compatibility for standard file paths
- Added comprehensive list of supported environment variables in documentation

## 2025-08-13 v0.0.22

- Added new `-p` command line flag for enabling source parsing functionality
- Enhanced `send_to_server_socket` method to accept and pass a `parse`
  parameter
- Modified `chat.rb` to handle the `parse` content flag from server messages
- Updated documentation in `README.md` with example usage of the new `-p` flag
- Added comprehensive tests for the new parsing functionality in
  `server_socket_spec.rb`
- Improved method documentation in `server_socket.rb` with detailed parameter
  descriptions
- Replaced `messages.list_conversation(2)` with `messages.show_last` in `/drop`
  command behavior
- Updated `gem_hadar` development dependency from version **1.27** to **2.0**
- Simplified SimpleCov setup by using `GemHadar::SimpleCov.start` instead of
  manual configuration

## 2025-08-11 v0.0.21

* **Vim Integration**: The `/vim` command allows users to insert the last chat
  message into a Vim server, improving workflow integration. It uses
  `--servername` and `--remote-send` to insert text at the cursor position and
  automatically indents based on the current column.
* **Improved Documentation**: Comprehensive documentation has been added to
  various modules and classes, making it easier for developers to understand
  and use the gem's features.
* **Model Selection Logic**: When only a single model is available, the code
  now automatically selects that model instead of showing a prompt, improving
  usability.
* **Configuration Handling**: Configuration file error handling has been
  updated to use `STDERR` for output, ensuring errors are displayed
  appropriately.

## 2025-08-11 v0.0.20

### Documentation

- Added more YARD-style documentation to all public methods throughout the
  codebase.

### Fixed

- **Message Output**:
  - Corrected `output(filename)` method to pass the message object to
    `write_file_unless_exist` for proper content writing.

## 2025-08-11 v0.0.19

* Added `/last` command to show last assistant message:
  * Introduced `show_last` method in `MessageList` class to display the last
    non-user message.
  * Extracted message formatting logic into `message_text_for` method for
    better code organization.
  * Updated documentation comments for improved clarity.
  * Updated `README.md` to document the new `/last` command.
* Added `/output` and `/pipe` commands for response handling:
  * Introduced `OllamaChat::MessageOutput` module with `pipe` and `output`
    methods.
  * Updated `MessageList#save_conversation` and `MessageList#load_conversation`
    to use `STDERR` for errors.
  * Added comprehensive error handling with exit code checking for pipe
    operations.
  * Updated help text to document new `/output` and `/pipe` commands.
* Sorted prompt lists for consistent ordering:
  * Ensured predictable prompt selection order in dialog interface.
* Removed RSpec describe syntax in favor of bare `describe`.
* Supported application/xml content type for RSS parsing:
  * Added `application/xml` MIME type support alongside existing `text/xml`.
  * Updated `OllamaChat::Parsing` module condition matching.
  * Added test case for `application/xml` RSS parsing.
  * Maintained other development dependencies at their current versions.
* Updated error message wording in parsing module.

## 2025-07-31 v0.0.18

* **Added /prompt command**: The `/prompt` command was added to the list of
  supported commands, allowing users to prefill their input with text from
  predefined prompts.
  + Integrated prompt handling in `lib/ollama_chat/chat.rb`, where a new case
    statement for `/prompt` sets up prefill functionality.
  + Implemented prompt selection using the `choose_prompt` method in
    `lib/ollama_chat/dialog.rb`.
  + Set up input hooks using `Reline.pre_input_hook` to insert selected prompts
    before user input.
* **Improved user interaction**:
  - Added model size display during model selection via the `model_with_size`
    method in `lib/ollama_chat/dialog.rb`.
  - Updated model selection logic to include formatted sizes in the display.
* **Optimized voice list generation**: In
  `lib/ollama_chat/ollama_chat_config/default_config.yml`, updated the voice
  list generation logic to use a more efficient method of retrieving voice
  names.

## 2025-07-14 v0.0.17

* Implement Pager Support for List Command
* Add simple command completion to chat
* Improved chat link generation
  + Changed `record.tags.first` to have prefix `?#` before the tag

## 2025-07-10 v0.0.16

- **New Features**
  - Added `-f CONFIG` option to `ollama_chat_send` for specifying configuration files.
  - Introduced `server_socket_runtime_dir` setting in the default config, and
  make it default to the current directory, allowing for a per directory chat
  to receive server socket messages.

- **Enhancements**
  - Improved logging with debug output for received server socket messages.
  - Refactored server socket handling:
    - Created `create_socket_server` method for UnixSocks setup with
      configurable runtime directories.
    - Updated `send_to_server_socket` and `init_server_socket` methods to use
      the new helper.
  - Changed evaluation rate metrics from 'c/s' to 't/s' for better clarity.

- **Documentation**
  - Added additional documentation for key classes and methods in `FollowChat`.

## 2025-07-02 v0.0.15

- **Enhanced `ollama_chat_send` and Unix Domain Socket Support:**
  - Added support for advanced parameters:
    - `-t`: Sends input as terminal commands.
    - `-r`: Enables two-way communication by waiting for and returning the server's response.
    - `-h` or `--help`: Displays usage information and available options.
  - Improved socket management using the `unix_socks` gem.
  - Enhanced message processing logic to handle different types of messages
    (`:socket_input`, `:terminal_input`, `:socket_input_with_response`).
- **Selector Support for Model and System Prompt Selection:**
  - Introduced `?selector` syntax to filter models and prompts.
  - Updated documentation to reflect this new feature.
  - Added a chooser dialog when multiple options match the selector.

## 2025-06-07 v0.0.14

* **Message List Improvements**:
  * Added thinking status to messages when chat is in think mode
  * Improved system prompt handling with new method documentation
* **Improved /system command handling for OllamaChat chat system**:
  * Added support for '/system [show]' command to show or change system prompt.
* Add conversation length to chat information display
* **Improvements to OllamaChat::SourceFetching**:
  * Fixed bug where document type concatenation could cause errors when `full?`
    returns `nil`, ensuring proper string formatting and avoiding potential
    crashes.

## 2025-06-05 v0.0.13

* **Improved chat command handling**
  - Added support for '/clear tags' to clear all tags.
  - Updated cases for 'history', 'all' and added case for 'tags'.
  - Added commands to clear documents collection and print a message in `information.rb`.
  - `OllamaChat::Chat#clean` now accepts 'tags' as an option.
* Apply read and write timeouts from configuration (300 seconds) for ollama server.
* Added method comments

## 2025-06-01 v0.0.12

* **API Compatibility**: Enforces Ollama API version `0.9.0` or higher to
  support new features like the `thinking` attribute.
* **Think Output Splitting**: When `think` is enabled, the API response is
  split into `content` and `thinking` fields, enabled by the new API version.
* **Think Mode Simplified**: The previous multi-mode `think_mode` system has
  been replaced with a boolean `think` switch for cleaner, more intuitive
  control.

## 2025-06-01 v0.0.11

* **Think Mode Implementation**:
  + Introduced `@think_mode` attribute to read think mode setting from config
  + Implemented `remove_think_blocks` method to filter out thought blocks from
    chat messages sent to the LLM model.
  + Added conditional logic based on `@think_mode` value to handle different
    modes
* **User Interface Improvements**:
  + Added `/think_mode` command to help users understand think mode options
  + Updated session output to include current think mode
  + Added think mode chooser to OllamaChat::Dialog, allowing users to select
    their preferred think mode
* **Output Handling Enhancements**:
  + Improved markdown handling for think blocks in OllamaChat::FollowChat class
  + Modified output to print clear screen, move home, and user info before
    printing content
* **Configuration Updates**:
  + Added `think_mode` key with value `"display"` to `default_config.yml`

## 2025-05-28 v0.0.10

* Simplify and improve command handling logic.
    * Update chat input handling to use a single `handle_input` method for all
      commands.
    * Add tests for various chat commands, including input handling, document
      policy selection, summarization, and more.
    * Improve test coverage for `DocumentCache`, `Information`, and other
      modules.
    * Improved handling of commands, e.g. **don't** when sending via
      `ollama_chat_send` by default.
* Added support for sending content to server socket with specific type.

## 2025-05-26 v0.0.9

* Improved tag parsing in OllamaChat:
  * Added regex validation for valid tags to `Documentrix::Utils::Tags`.
  * Modified `parse_content` method in `OllamaChat::Parsing` to handle valid
    tag formats.
  * Updated `scan` methods in `content` processing to more correctly identify
    tags.
* Added option to explicitly open socket for receiving input from
  `ollama_chat_send`:
  * Added new command-line option `-S` to enable server socket functionality.
  * Updated `OllamaChat::Chat` class to include server socket initialization
    based on the new option.
  * Modified usage message in `README.md` and `information.rb` files.

## 2025-05-23 v0.0.8

* Introduce `fix_config` method to rescue `ComplexConfig` exceptions and prompt
  user for correction.
  * Added section to README.md on using `ollama_chat_send` to send input to a
  running `ollama_chat` process.
* Fix path existence check and cleanup on server socket initialization.
  * Added check for existing path at
    `OllamaChat::ServerSocket.server_socket_path` to prevent overwrite.
  * Clean up server socket file if it exists when leaving thread.

## 2025-05-22 v0.0.7

* Added `ollama_chat_send` executable in `/bin`, required `ollama_chat` gem,
  sent user input to Ollama server via
  `OllamaChat::ServerSocket.send_to_server_socket` method and handled
  exceptions and exit with non-zero status code if an error occurs.
* Added new `server_socket.rb` file containing module and methods for
  server-side socket handling, modified `chat.rb` to include `ServerSocket`
  module and use its `init_server_socket` method to start server socket,
  updated `chat.rb` to handle incoming messages from server socket in
  interactive loop sent via `send_to_server_socket`.
* Refactored chat history management into separate module by adding
  OllamaChat::History module, including History in OllamaChat::Chat and moving
  chat history methods to new History module.
* Refactored chat history configuration by making chat history filename use
  config setting first instead of environment variable OLLAMA_CHAT_HISTORY.
* Updated chat commands and documentation by updating `/clear`, `/collection`,
  `/links` command helps to use more consistent syntax, updated
  `OllamaChat::Information` module in `lib/ollama_chat/information.rb` to
  reflect changes.
* Added support for chat history loading and saving by adding `require
  'tins/secure_write'` and `require 'json'` to dependencies, modified
  OllamaChat::Chat class to initialize, save, and clear chat history, utilized
  `File.secure_write` for secure saving of chat history.

## 2025-04-15 v0.0.6

* Updated Rakefile to use `ollama-ruby` version **1.0**.
* Modified `model_present?` method in `lib/ollama_chat/model_handling.rb` to
  use `ollama.show(model:)`.
* Changed `pull_model_from_remote` method in
  `lib/ollama_chat/model_handling.rb` to use `ollama.pull(model:).
* Updated `ollama_chat.gemspec` to use `ollama-ruby` version **1.0** and
  updated date to **2025-04-14**.
* Attempt to capture stderr as well by redirecting stderr to stdout for
  commands that output to it always or in the error case.
* Updated development dependencies in `ollama_chat.gemspec`.

## 2025-03-22 v0.0.5

* Updated default config to use environment variable for Searxng URL:
  * Changed `url` field in `searxng` section of `default_config.yml`.
  * Replaced hardcoded URL with expression that fetches value from
    `OLLAMA_SEARXNG_URL` environment variable.
* Handle Ollama server disconnection:
  * Added error handling for `Ollama::Errors::TimeoutError`.
  * Print error message when connection is lost.
* Output last exchange of a loaded conversation:
  * Add attribute reader to `messages` in `lib/ollama_chat/chat.rb`.
  * Replace `@messages` with `messages` in method calls throughout the class.
  * Update conversation listing, clearing, dropping, saving, loading methods.
  * Refactor interaction with user logic.
  * Update tests in `spec/ollama_chat/chat_spec.rb`.

## 2025-02-21 v0.0.4

* Added support for web searching with SearXNG:
  + Added `ollama_chat/web_searching.rb` module which includes a generic
    `search_web` method that uses the selected search engine.
  + Updated `ollama_chat/default_config.yml` to include configuration options
    for web searching with all engines.
  + Updated `ollama_chat/chat.rb` to use the new `web_searching` module and
    updated the `search_web` method to return results from either engine.
  + Added specs in `spec/ollama_chat/web_searching_spec.rb` to test the new
    functionality.
* Added ollama chat version display to information module and spec:
  + Added `STDOUT.puts` for displaying ollama chat version in
    `lib/ollama_chat/information.rb`
  + Updated test in `spec/ollama_chat/chat_spec.rb` to include new output
    string
* Update chat document redis cache expiration time default to 0.

## 2025-02-17 v0.0.3

* Support setting of request headers:
    * Added `request_headers` option to `default_config.yml
    * Updated `OllamaChat::SourceFetching` module to pass
      `config.request_headers?.to_h` to `Fetcher.get`
    * Updated `OllamaChat::Utils::Fetcher.get` method to take an optional
      `headers:` parameter
    * Updated tests for Fetcher utility to include new headers option
* Refactoring
    * Added `connect_to_ollama_server` method to `spec_helper.rb`
    * Stubbed API requests for tags, show, and version in this method
    * Removed stubbing of API requests from individual specs
* Add support for ollama server version display:
  * Add `server_version` method to display connected ollama server version
  * Update `info` method to use new `server_version` method
  * Add **6.6.6** as reported API version in `spec/assets/api_version.json`
* Updated chat spec to use 'test' collection:
  * Updated `argv` let in OllamaChat::Chat describe block to pass '-C test'
    option to be isolated from 'default' collection
  * Updated output of collection stats display to reflect 'test' collection

## 2025-02-11 v0.0.2

* Improved handling of location in MessageList class:
  * Use assistant system prompt (`assistant_system_prompt`) for adding location
    to message list, if no system prompt was defined.
  * Updated spec to cover new behavior.
* Simplified configuration defaults to be stored in `default_config.yml`:
  - Replaced `DEFAULT_CONFIG` hash with a single line of code that reads from
    `default_config.yml`
  - Created new file `default_config.yml` in the same directory, containing the
    old `DEFAULT_CONFIG` hash values
  - Updated `initialize` method to use the new `default_config.yml` file if no
    filename is provided

## 2025-02-02 v0.0.1

* Renamed `documents` variable to `@documents` in `OllamaChat::Chat`
    * Modified `add_documents_from_argv` method to accept only `document_list`
      as argument
    * Updated spec for `OllamaChat::Chat` to reflect changes in
      `add_documents_from_argv` method
* Use `clamp(1..)` instead of manual checks for `n.to_i` in source fetching
* Dropped is now used consistently in the code for message popping
* Set up Redis environment and service for development:
  * Added `.envrc` file with Redis URL exports.
  * Added `docker-compose.yml` file to define a Redis service:
  * Added `redis.conf` file with basic settings:
* Use method names rather than instance variables for switch access.

## 2025-01-29 v0.0.0

  * Start
