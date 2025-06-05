# Changes

## 2025-06-05 v0.0.13

* Improved chat command handling
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
  + Implemented `remove_think_blocks` method to filter out thought blocks from chat messages sent to the LLM model.
  + Added conditional logic based on `@think_mode` value to handle different modes
* **User Interface Improvements**:
  + Added `/think_mode` command to help users understand think mode options
  + Updated session output to include current think mode
  + Added think mode chooser to OllamaChat::Dialog, allowing users to select their preferred think mode
* **Output Handling Enhancements**:
  + Improved markdown handling for think blocks in OllamaChat::FollowChat class
  + Modified output to print clear screen, move home, and user info before printing content
* **Configuration Updates**:
  + Added `think_mode` key with value `"display"` to `default_config.yml`

## 2025-05-28 v0.0.10

* Simplify and improve command handling logic.
    * Update chat input handling to use a single `handle_input` method for all commands.
    * Add tests for various chat commands, including input handling, document
      policy selection, summarization, and more.
    * Improve test coverage for `DocumentCache`, `Information`, and other modules.
    * Improved handling of commands, e.g. **don't** when sending via `ollama_chat_send` by default.
* Added support for sending content to server socket with specific type.

## 2025-05-26 v0.0.9

* Improved tag parsing in OllamaChat:
  * Added regex validation for valid tags to `Documentrix::Utils::Tags`.
  * Modified `parse_content` method in `OllamaChat::Parsing` to handle valid tag formats.
  * Updated `scan` methods in `content` processing to more correctly identify tags.
* Added option to explicitly open socket for receiving input from `ollama_chat_send`:
  * Added new command-line option `-S` to enable server socket functionality.
  * Updated `OllamaChat::Chat` class to include server socket initialization based on the new option.
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
* Modified `model_present?` method in `lib/ollama_chat/model_handling.rb` to use `ollama.show(model:)`.
* Changed `pull_model_from_remote` method in `lib/ollama_chat/model_handling.rb` to use `ollama.pull(model:).
* Updated `ollama_chat.gemspec` to use `ollama-ruby` version **1.0** and updated date to **2025-04-14**.
* Attempt to capture stderr as well by redirecting stderr to stdout for
  commands that output to it always or in the error case.
* Updated development dependencies in `ollama_chat.gemspec`.

## 2025-03-22 v0.0.5

* Updated default config to use environment variable for Searxng URL:
  * Changed `url` field in `searxng` section of `default_config.yml`.
  * Replaced hardcoded URL with expression that fetches value from `OLLAMA_SEARXNG_URL` environment variable.
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
  + Added specs in `spec/ollama_chat/web_searching_spec.rb` to test the new functionality.
* Added ollama chat version display to information module and spec:
  + Added `STDOUT.puts` for displaying ollama chat version in `lib/ollama_chat/information.rb`
  + Updated test in `spec/ollama_chat/chat_spec.rb` to include new output string
* Update chat document redis cache expiration time default to 0.

## 2025-02-17 v0.0.3

* Support setting of request headers:
    * Added `request_headers` option to `default_config.yml
    * Updated `OllamaChat::SourceFetching` module to pass `config.request_headers?.to_h` to `Fetcher.get`
    * Updated `OllamaChat::Utils::Fetcher.get` method to take an optional `headers:` parameter
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
    * Modified `add_documents_from_argv` method to accept only `document_list` as argument
    * Updated spec for `OllamaChat::Chat` to reflect changes in `add_documents_from_argv` method
* Use `clamp(1..)` instead of manual checks for `n.to_i` in source fetching
* Dropped is now used consistently in the code for message popping
* Set up Redis environment and service for development:
  * Added `.envrc` file with Redis URL exports.
  * Added `docker-compose.yml` file to define a Redis service:
  * Added `redis.conf` file with basic settings:
* Use method names rather than instance variables for switch access.

## 2025-01-29 v0.0.0

  * Start
