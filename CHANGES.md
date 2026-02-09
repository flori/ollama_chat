# Changes

## 2026-02-10 v0.0.65

- Updated `location_handling.rb` to return only `location_name`,
  `location_decimal_degrees`, and `units`
- Removed `localtime` from `location_data` and prompt template in
  `lib/ollama_chat/location_handling.rb`
- Updated `default_config.yml` location prompt to exclude `on %{localtime}`
- Simplified location switch messages in `switches.rb`
- Added new tool `GetTime` in `lib/ollama_chat/tools/get_time.rb` returning
  ISO8601 time
- Updated `tools.rb` to require `get_time`
- Updated `tools/get_location.rb` comments and description
- Added `get_time_spec.rb` to `test_files` listing
- Added `get_time.rb` to `extra_rdoc_files` and `files` listings
- Removed duplicate `get_time.rb` entries from `extra_rdoc_files` and `files`
  listings
- Updated specs: `message_list_spec.rb`, `tools/get_location_spec.rb`, added
  `tools/get_time_spec.rb`
- Adjusted regexes in specs to match new prompt format
- Removed unused `time` field from `location_data` in tests

## 2026-02-09 v0.0.64

- Added new `OllamaChat::Tools::GetJiraIssue` tool for fetching JIRA issue
  information
- Introduced `ConfigMissingError` exception for handling missing configuration
- Added JIRA tool configuration in `OllamaChat::EnvConfig` with `URL`, `USER`,
  and `API_TOKEN` settings
- Updated `default_config.yml` to include `get_jira_issue` tool with `default:
  false`
- Enhanced `OllamaChat::Utils::Fetcher` to support additional options and
  middleware
- Added comprehensive tests for the new `get_jira_issue` tool in
  `spec/ollama_chat/tools/get_jira_issue_spec.rb`
- Updated tool registration to include the new `get_jira_issue` tool

## 2026-02-09 v0.0.63

- Added `OllamaChat::Utils::PathValidator` module with `assert_valid_path`
  helper and `OllamaChat::InvalidPathError` exception
- Refactored `FileContext`, `ReadFile`, and `WriteFile` tools to use new path
  validation logic
- Simplified `OllamaChat::Tools::FileContext` to use glob pattern only,
  removing the `path` parameter
- Added `ignore_case` flag to `execute_grep` tool with dynamic command
  construction using `eval_template`
- Renamed tool classes and files to more descriptive names:
  - `browser.rb` → `browse.rb` (class `Browser` → `Browse`)
  - `grep.rb` → `execute_grep.rb` (class `Grep` → `ExecuteGrep`)
  - `weather.rb` → `get_current_weather.rb` (class `Weather` → `GetCurrentWeather`)
  - `cve.rb` → `get_cve.rb` (class `CVE` → `GetCVE`)
  - `endoflife.rb` → `get_endoflife.rb` (class `EndOfLife` → `GetEndoflife`)
  - `location.rb` → `get_location.rb` (class `Location` → `GetLocation`)
  - `file_reader.rb` → `read_file.rb` (class `FileReader` → `ReadFile`)
  - `file_writer.rb` → `write_file.rb` (class `FileWriter` → `WriteFile`)
- Updated `follow_chat.rb` to use `require_confirmation?` instead of `confirm?`
  when checking tool confirmation
- Added scheme whitelist to `ImportURL` tool with `schemes: [http, https]`
  configuration
- Introduced `read_file` tool with path validation and error handling
- Added `run_tests` tool for executing RSpec or Test-Unit test suites with
  configurable runner and coverage reporting
- Added `vim_open_file` tool for remote Vim file opening with line range
  support
- Enhanced `OllamaChat::Vim` class with file opening and line/range selection
  capabilities
- Added `GemPathLookup` tool to find gem installation paths using Bundler
- Added `valid_json?` method to `OllamaChat::Tools::Concern` for consistent
  JSON validation
- Implemented `ImportURL` tool for fetching web content

## 2026-02-07 v0.0.62

**Tool Execution**  
- All tools now return structured JSON errors (`error` + `message`).  
- Confirmation prompts (`confirm?`) added to `OllamaChat::FollowChat`.  
- `infobar` displays a busy indicator and status messages during tool runs.  
- Tool methods accept `config:` and `chat:` keyword arguments.

**Tool Registration**  
- Centralized logic via `OllamaChat::Tools::Concern` to prevent duplicate
  registrations.

**File Context Tool (`file_context`)**  
- Supports an exact `path:` argument in addition to `directory:` + `pattern:`.  
- Uses `blank?` for argument validation.  
- YARD documentation added.

**Directory Structure Tool (`directory_structure`)**  
- Delegates to `OllamaChat::Utils::AnalyzeDirectory.generate_structure`.  
- Excludes hidden files, symlinks, and the `pkg` directory by default.  
- `exclude` option configurable in `default_config.yml`.

**Utility Module**  
- New `OllamaChat::Utils::AnalyzeDirectory` containing the `generate_structure`
  method.

**Error Handling**  
- `CVE`, `EndOfLife`, `Grep`, and `Weather` tools now catch all exceptions and return structured JSON errors.

**Testing**  
- Added comprehensive specs for `AnalyzeDirectory` (traversal, exclusions,
  error handling).  
- Tests for exact `path` usage in `file_context` with conflict detection.  
- Updated `test_files` list in the gemspec.

**Configuration**  
- `directory_structure` accepts an `exclude` option via `default_config.yml`.  
- Tool signatures updated to accept `config:` and `chat:`.

**Gem Specification**  
- Updated `test_files`, `extra_rdoc_files`, and `files` arrays to include new
  utilities, tests, and documentation.

## 2026-02-06 v0.0.61

### New Features
- Added new `OllamaChat::Tools::Grep` tool to enable grep command execution
- Introduced `execute_grep` tool configuration with `default: true` and `cmd`
  template

### Tool Improvements
- Updated `tools.rb` to always call `.new` on tool classes during registration
- Removed `depth` parameter from `DirectoryStructure` tool
- Simplified `generate_structure` method to recursively build directory
  structure without depth handling

### Security Enhancements
- Added `require 'shellwords'` for secure argument handling
- Implemented `execute` method in `Grep` tool using `Shellwords.escape` for
  security and `OllamaChat::Utils::Fetcher`

### Documentation & Testing
- Updated tests for `DirectoryStructure` tool to use only `path` argument and
  test defaulting to `.` (current directory)
- Added `lib/ollama_chat/tools/grep.rb` and
  `spec/ollama_chat/tools/grep_spec.rb` to test files and extra rdoc files
- Updated `ollama_chat.gemspec` version to **0.0.61**

### Implementation Details
- Implemented `execute` method in `Grep` tool using `Shellwords.escape` for
  security and `OllamaChat::Utils::Fetcher`
- Updated `tools.rb` to always call `.new` on tool classes during registration
- Enhanced `DirectoryStructure` tool documentation and method signatures
- Improved error handling in `Grep` tool with proper rescue blocks

## 2026-02-06 v0.0.60

### New Features
- Added `directory_structure` tool to provide directory listing capabilities
- Added `file_context` tool to provide file content context
- Added `execute_grep` tool to provide grep command execution capability

### Core Functionality
- Implemented `OllamaChat::Tools` module for tool registration and management
- Added `OllamaChat::Tools::FileContext` tool for file content retrieval
- Added `OllamaChat::Tools::DirectoryStructure` tool for directory listing
- Added `OllamaChat::Tools::Grep` tool for grep command execution
- Implemented `OllamaChat::Chat` class for chat interaction with Ollama
- Added `

## 2026-02-06 v0.0.60

### New Features
- Added `OllamaChat::LocationHandling` module for location data management
- Introduced `get_location`, `file_context`, and `directory_structure` tools
- Implemented recursive directory traversal with depth limiting and hidden file
  skipping

### Tool Enhancements
- Enhanced tool calling system to pass `chat: @chat` to tool execution
- Updated `@enabled_tools` initialization to use default tool configurations
- Implemented automatic tool class instantiation in the `register` method
- Configured new tools to be disabled by default in `default_config.yml`

### Technical Improvements
- Added dynamic format conversion with `send("to_#{format.downcase}")`
- Updated `MessageList#at_location` to use the new location handling approach
- Enhanced `list_tools` output with visual enabled/disabled indicators
- Integrated location data into system prompts via `location_description`
  method

### Documentation & Testing
- Added comprehensive YARD documentation for location handling and tools
- Added new tool files and test files to gemspec's `s.files`, `s.test_files`,
  and `s.extra_rdoc_files`
- Added comprehensive test coverage for new tools and location handling

### Configuration
- Updated default tool configuration to use `config.tools.to_h.map` for tool
  registration
- Configured new tools to be disabled by default in `default_config.yml`

### Code Structure
- Updated gemspec to include new files and test files
- Refactored `InputContent` to use dynamic format conversion
- Enhanced `FollowChat` to pass chat instance to tool execution
- Updated `MessageList#at_location` to use new location handling approach

## 2026-02-05 v0.0.59

### New Features

- **Dynamic Tool Management**: Added `/tools` command with subcommands `/tools
  enable` and `/tools disable` for listing, enabling, or disabling tools
  dynamically

- **Three Built-in Tools**:
  - `get_current_weather` - Fetches real-time temperature from German Weather
    Service (DWD)
  - `get_cve` - Retrieves CVE details from MITRE API
  - `get_endoflife` - Queries endoflife.date API for software lifecycle
    information

### Technical Improvements

- **Tool Calling System**: Implemented comprehensive tool management using
  `@enabled_tools` array
- **Configuration Support**: Added tool configurations in `default_config.yml`
- **Integration**: Enhanced `Ollama::Chat` with proper tool calling integration
  and `Ollama::Tool` support
- **Error Handling**: Robust error handling for external API calls with proper
  fallbacks

### Documentation & Testing

- Updated README with new tool management commands
- Added comprehensive RSpec tests for all three new tools
- Enhanced gemspec with updated file listings and dependencies
- Implemented caching for HTTP responses using
  `OllamaChat::Utils::CacheFetcher`

### Code Structure

- **New Modules**: `OllamaChat::ToolCalling`, `OllamaChat::Tools::CVE`,
  `OllamaChat::Tools::EndOfLife`, `OllamaChat::Tools::Weather`
- **Enhanced Classes**: `OllamaChat::Chat` with tool management and `DWDSensor`
  for weather data retrieval
- **Dependency**: Added `rubyzip` for DWD data processing

This release transforms OllamaChat from a chat interface into a smart assistant
capable of executing external tools and accessing real-world data.

## 2026-02-02 v0.0.58

- Updated Redis image to version to valkey **9.0.1** in docker-compose.yml
- Added `errors.lst` to `.gitignore` and updated packaging to ignore this file
- Added `utils` gem as a development dependency in `Rakefile` and
  `ollama_chat.gemspec`
- Enhanced documentation consistency with standardized leading spaces for doc
  comment continuation lines
    - Standardized parameter and return value descriptions for methods to align
      with YARD documentation standards
    - Ensured all method signatures and descriptions comply with YARD documentation
      standards

## 2026-01-21 v0.0.57

- Introduce `OllamaChat::StateSelectors` module with `StateSelector` class for
  managing configurable states
- Replace simple string-based document policy and think mode with
  `StateSelector` objects
- Add `allow_empty` parameter to `StateSelector#initialize` method to allow
  empty states in voice output
- Update `StateSelector#selected=` to conditionally validate states based on
  `allow_empty?`
- Refactor voice handling to use `StateSelector` by replacing `@current_voice`
  with `@voices` `StateSelector`
- Update `FollowChat` to use `@voices.selected` instead of `@current_voice` for
  voice selection
- Simplify `change_voice` method in `dialog.rb` to delegate to `@voices.choose`
- Update voice display in `information.rb` to use `@voices.show` instead of raw
  voice name
- Update configuration format to support nested `think` settings with `mode`
  and `loud` sub-properties
- Modify command handlers to use `document_policy.choose` and
  `think_mode.choose` instead of legacy methods
- Update `OllamaChat::Chat` initialization to use `setup_state_selectors`
  method
- Refactor `OllamaChat::ThinkControl` to use new state selector system
- Update `OllamaChat::Parsing` to reference `@document_policy.selected` instead
  of `@document_policy`
- Update default configuration file to use format with nested think settings
- Add proper `attr_reader` for `document_policy` and `think_mode` state
  selectors
- Update help text to reference new state selector system
- Update `OllamaChat::Switches` to handle nested think configuration
- Add `OllamaChat::StateSelectors` to required files in `lib/ollama_chat.rb`

## 2026-01-17 v0.0.56

- Updated `context_spook` dependency from version **1.4** to **1.5**
- Expanded context file inclusion to support YAML files
- Updated `context_spook` method to pass `format` parameter to
  `ContextSpook::generate_context` calls
    - Added `context` section to default configuration with `format: JSON` setting
- Added `/reconnect` command to reset Ollama connection
    - Introduced `connect_ollama` method to create new Ollama client instances with
      current configuration
    - Added `base_url` method to resolve connection URL from command-line or
      environment config
    - Updated `handle_input` to process `/reconnect` command and trigger
      reconnection
- Enhanced `OllamaChat::InputContent#input` method to select and read multiple
  files matching a glob pattern
    - Updated `OllamaChat::InputContent#choose_filename` to accept a `chosen`
      parameter for tracking selections
    - Modified test cases in `spec/ollama_chat/input_content_spec.rb` to verify
      multiple file selection behavior
    - Files are now concatenated with filename headers in the output
    - Maintains backward compatibility with single file selection
    - Uses `Set` for efficient duplicate prevention during selection
- Removed specialized CSV parsing functionality from `OllamaChat::Parsing`
  module
- Handle nil from `STDIN.gets` to prevent `NoMethodError`

## 2026-01-08 v0.0.55

- Added `OllamaChat::Vim` class for inserting text into Vim buffers using the
  clientserver protocol
- Implemented `server_name` and `clientserver` attribute readers for the
  `OllamaChat::Vim` class
- Enhanced error message for missing vim server to include the specific server
  name being used
- Added error handling to the `insert` method with fallback to `STDERR` output
  when vim command fails
- Added comprehensive specs for `OllamaChat::Vim` module with **100%** coverage
- Fixed typo in help text for `ollama_chat_send` command ("reqired" →
  "required")
- Added comprehensive tests for `ThinkControl` module with **100%** coverage
- Updated `README.md` and `OllamaChat::Information` to document the new
  `/revise_last` command
- Improved test coverage for Vim integration
- Ensured proper state management and no side effects during selection in
  `ThinkControl` tests
- All tests use `connect_to_ollama_server` for proper setup
- Fixed edge cases including exit conditions and nil selections in
  `ThinkControl` tests
- Included tests for combined logic with `think_loud` switch in `ThinkControl`
  tests

## 2026-01-08 v0.0.54

### New Features

- Added `/revise_last` command for editing the last message
- Implemented `OllamaChat::MessageEditing` module with editor integration
- Enhanced message editing with proper error handling and user feedback

### Improvements

- Improved `InputContent` module with better error handling (replaced `$?` with
  direct `system` return)
- Updated `choose_filename` to use `_1` parameter for Ruby idioms
- Added comprehensive test suite for `InputContent` module with **100%** line
  coverage

## 2026-01-07 v0.0.53

- Added `/compose` command functionality to compose content using an external
  editor
    - Introduced `OllamaChat::EnvConfig::EDITOR?` and
      `OllamaChat::EnvConfig::EDITOR!` methods for editor configuration access
    - Implemented `compose` method in `InputContent` module using `Tempfile` for
      temporary file handling
    - Added `EDITOR` configuration with default value of `vim` or `vi` if available
    - Updated help text to include the new `/compose` command
    - Added graceful error handling for editor failures, returning `nil` and
      printing error to `STDERR`
    - Required `tempfile` gem for temporary file handling functionality

## 2026-01-06 v0.0.52

- Enabled verbose context generation to provide real-time feedback during
  context collection operations
- Improved user experience by monitoring context size for LLM token limit
  considerations
- Added better feedback mechanisms to help users gauge processing time during
  context generation

## 2026-01-06 v0.0.51

- Added `/input` command to allow users to select files using glob patterns
  like `src/*.c` or `**/*.rb`
    - Implemented `input` method in `OllamaChat::Chat` class using `Dir.glob` for
      pattern matching
    - Integrated with `OllamaChat::Utils::Chooser` for interactive file selection
    - Added `/input` command to help text in `OllamaChat::Information` module
    - Supports default pattern `**/*` when no argument is provided
    - Returns file content as string for use in chat conversations
- Integrated `/context` command in `OllamaChat::Chat` with pattern matching
  support
    - Updated `display_chat_help_message` to document `/context [pattern...]`
      command
    - Modified `README.md` to include `/context` command in help section
    - Introduced `context_spook` **~> 1.1** dependency
    - Created `OllamaChat::InputContent` module with `input`, `choose_filename`,
      and `context_spook` methods
    - Extracted input functionality from `Chat` class to `InputContent` module for
      better organization
    - Support both static context files (`.contexts/*.rb`) and dynamic pattern
      matching (`lib/**/*.rb`)
    - Implemented proper content handling with `@parse_content = false` to prevent
      parsing of URLs
    - Used `File.file?` instead of `File.stat(it).file?` for cleaner file checking
    - Support multiple space-separated patterns in `/context` command
- Added comprehensive YARD documentation for all new methods and parameters
- Improved pipe command handling with dynamic command resolution
- Moved `RedisCache` class comment

## 2026-01-03 v0.0.50

- Use Redis-based expiring cache implementation with the new
  `OllamaChat::RedisCache` class
- Replaced `Documentrix::Documents::RedisCache` with `OllamaChat::RedisCache`
  in the `setup_cache` method
- Updated `GemHadar` development dependency to version **2.16.3**
- Integrated changelog generation capability into GemHadar configuration
- Updated Redis image to valkey version **8.1.5** with latest bug fixes and
  improvements
- Improved file path resolution using `Pathname` for better handling of
  relative paths and home directory shortcuts
- Enhanced test suite configuration and stubbing for more consistent test
  execution
- Updated Ruby image tag to stable **4.0**-alpine
- Added `lib/ollama_chat/redis_cache.rb` to `extra_rdoc_files` and `files`
  lists in gemspec
- Added `spec/ollama_chat/redis_cache_spec.rb` to `test_files` list in gemspec
- Removed duplicate entry for `lib/ollama_chat/redis_cache.rb` from `files`
  list
- Improved test setup for source fetching with explicit configuration file

## 2025-12-24 v0.0.49

- Updated `unix_socks` gem dependency from **~> 0.2** to **~> 0.3**
- Replaced `UnixSocks::Server` with `UnixSocks::DomainSocketServer` in
  `lib/ollama_chat/server_socket.rb`
- Updated test expectations in `spec/ollama_chat/server_socket_spec.rb` to
  match new class name
- Bumped `gem_hadar` development dependency from **>= 2.16.0** to **>= 2.16.2**

## 2025-12-23 v0.0.48

- Updated `unix_socks` dependency to version **0.2.3**

## 2025-12-23 v0.0.47

- Handle existing socket file conflicts gracefully by implementing logic to
  detect and manage conflicts
- Added user prompt to remove stale socket files when conflicts occur during
  socket creation
- Improved error handling for `Errno::EEXIST` exceptions during socket creation
  process
- Enhanced user experience with clear warnings and recovery options for socket
  file conflicts
- Socket file cleanup now uses `FileUtils.rm_f` for safe removal of conflicting
  files
- Added retry mechanism after successful socket file removal to ensure proper
  socket creation
- Exit with error code **1** when user declines socket file removal prompt
- Add changelog file to gem distribution using `GemHadar` with filename
  `CHANGES.md`
- Update `unix_socks` dependency to include minimum version **0.2.2** by
  bumping `gem_hadar` development dependency to **>= 2.16.0** in
  `ollama_chat.gemspec`

## 2025-12-20 v0.0.46

- Updated `rake` command in `.all_images.yml` to use `bundle exec rake spec`
  for consistent test execution
- Added `bigdecimal` dependency with version **3.1** to ensure proper decimal
  arithmetic operations
- Updated test expectation for `puts` to include an empty string parameter in the argument list
- Updated `documentrix` dependency to version **0.0.4** or higher for runtime dependencies
- Updated `ollama-ruby` dependency from version **1.16** to **1.18** and then to **1.19**
- Updated `unix_socks` dependency from version **0.1** to **1.2**
- Updated required Ruby version from `~> 3.2` to `>= 3.2` to allow usage with Ruby **3.2** and higher
- Added Ruby **4.0-rc** image configuration with script settings
- Updated `rubygems` version from **3.7.2** to **4.0.2**
- Updated `gem_hadar` development dependency from ~> **2.8** to ~> **2.10**

## 2025-12-10 v0.0.45

- Enhanced `OllamaChat::FollowChat` class output formatting
- Made `display_formatted_terminal_output` method accept optional output parameter
- Improved handling of chomping content and thinking text to prevent trailing whitespace
- Properly routed markdown vs non-markdown output through correct display methods
- Added extra blank line before evaluation statistics for better visual separation
- Updated bundle command to include --all flag

## 2025-12-10 v0.0.44

- Fixed `stream` option in `spec/ollama_chat/follow_chat_spec.rb` from `on?
  true` to `on?: true`
- Extracted `prepare_last_message` method to handle content and thinking text
  formatting with markdown and annotation support
- Introduced `display_output` method that uses `use_pager` from `MessageList`
  to handle large outputs gracefully
- Modified `FollowChat#process_response` to conditionally call
  `display_formatted_terminal_output` based on `@chat.stream.on?`
- Added `use_pager` method to `MessageList` that wraps output blocks with pager
  context using `Kramdown::ANSI::Pager`
- Updated conditional logic in `follow_chat.rb` to properly distinguish between
  streaming and non-streaming display modes
- Updated `kramdown-ansi` dependency version from `~> 0.2` to `~> 0.3` in
  `Rakefile` and `ollama_chat.gemspec`
- Added `truncate_for_terminal` method to `OllamaChat::FollowChat` class that
  limits text to a specified number of lines
- Modified `display_formatted_terminal_output` to use `truncate_for_terminal`
  when processing content and thinking text
- Updated spec file to expose the `FollowChat` instance for testing
- Added comprehensive tests for the new `truncate_for_terminal` method covering
  various line count scenarios
- The method handles edge cases like negative and zero line counts by returning
  the last line
- Uses `Tins::Terminal.lines` as default maximum lines parameter
- The implementation ensures terminal output stays within display limits while
  preserving content integrity

## 2025-12-09 v0.0.43

- Added retry logic in `interact_with_user` method to handle
  `Ollama::Errors::BadRequestError` when in think mode
- Introduced `think_loud` switch with associated UI commands and logic in
  `chat.rb`
- Implemented `OllamaChat::ThinkControl` module in
  `lib/ollama_chat/think_control.rb` with methods `think`, `choose_think_mode`,
  `think?`, and `think_show`
- Updated `ollama-ruby` dependency from version **1.14** to **1.16**
- Simplified think mode handling and updated related tests
- Added string modes support for think feature allowing values `"low"`,
  `"medium"`, `"high"`
- Modified `FollowChat` to conditionally append thinking annotations based on
  `think_loud.on?`
- Updated documentation comments to follow new tagging conventions for method
  returns and attribute accessors
- Updated `default_config.yml` to set `think_loud: true` by default
- Modified information display to include `think_loud.show`
- Adjusted tests to mock `think_loud` and verify annotation handling
- Updated `follow_chat_spec.rb` to stub `think_loud?` instead of
  `think_loud.on?`

## 2025-12-03 v0.0.42

- Updated `ollama-ruby` gem dependency from version **1.7** to **1.14**
- Fixed JSON serialization issues with image data in Ollama messages
- Ensured proper base64 encoding and formatting of image URLs
- Added spec for `display_config` method in `OllamaChat::Information` module
- Replaced explicit `my_pager` variable with `OllamaChat::EnvConfig::PAGER?` lookup
- Enabled users to customize pager behavior through environment configuration
- Updated `lib/ollama_chat/ollama_chat_config/default_config.yml` to prevent shell expansion in voice list command
- Changed `say -v ?` to `say -v '?'` to prevent shell expansion and potential hanging issues

## 2025-11-20 v0.0.41

- Fixed message output specification and removed duplicate expectation
- Added `clientserver` configuration option to `vim` section in `default_config.yml`
- Updated `OllamaChat::Vim` to accept `clientserver:` keyword argument in `initialize`
- Modified `insert` and `col` methods in `vim.rb` to use `--clientserver` flag
- Passed `clientserver` from `chat.rb` when creating `OllamaChat::Vim` instance
- Set default `clientserver` value to **socket**

## 2025-11-20 v0.0.40

- Improved Vim server name generation to ensure uniqueness by replacing
  `Pathname.pwd.to_s.upcase` with `File.basename` and `Digest::MD5.hexdigest`
- Modified `default_server_name` method to create server names in the format
  `MYAPP-3F2B4D8A` instead of just `MYAPP`
- Enhanced documentation for `OllamaChat::Vim#initialize` and `OllamaChat::Vim.default_server_name` methods

## 2025-11-14 v0.0.39

- Updated `tins` dependency version from `~> 1.41` to `~> 1.47` in `Rakefile` and `ollama_chat.gemspec`
- Updated clipboard command to use `ctc` for cross-platform support, which acts
  as a wrapper to copy stdin to the clipboard

## 2025-11-11 v0.0.38

- Added `ask?` method call to confirm overwriting existing files when saving
  conversations
- Modified `save_conversation` in `OllamaChat::Conversation` to prompt before
  overwriting
- Removed explicit file existence check from `MessageList#save_conversation`
- Both `/save` and `/output` commands now support overwrite confirmation
- Replace `write_file_unless_exist` method with `attempt_to_write_file`
- Add user confirmation prompt before overwriting existing files
- Update method documentation to reflect new overwrite behavior
- Modify file writing logic to use `attempt_to_write_file` instead of direct
  write
- Update `output` method to check return value of `attempt_to_write_file`
  before printing success message
- Removed `xdg` gem from the list of dependencies in `code_indexer` block

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
