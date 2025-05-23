# Changes

## 2025-05-22 v0.0.7

* Added `ollama_chat_send` executable in `/bin`, required 'ollama_chat' gem,
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
