# Changes

## 2026-11-25 v0.0.150

### Features

- Added a hidden `:enter` command that opens the prompt template chooser when
  pressing Enter on an empty input line. The selected template is prefilled
  into the readline buffer for review.
- Introduced a new `internal` context for prompt templates to separate
  application-interpolated prompts (e.g., `embed`, `summarize`, `persona`) from
  human-facing `prompt` templates.
- Added four new default nudge prompts (`nudge`, `yep`, `nope`, `decide`) under
  the `prompt` context to provide useful defaults in the Enter-chooser.

### Improvements

- Extracted shared logic for choosing and prefiling or editing prompt templates
  into `PromptManagement#select_prompt_for_input`.
- Updated the `execute_grep` tool's default command template to include `-nH
  -I` flags and exclude `.git` and `vendor` directories, improving output
  formatting and reducing noise from binary files and version control
  directories.
- Implemented auto-acknowledgment in `AppState.seed` for contexts that only
  gained new prompts, preventing unnecessary boot notifications for app-shipped
  additions.
- Added database migration `013` to relocate existing default prompt rows from
  the `prompt` context to the `internal` context.

### Fixes

- Updated 17 call sites to explicitly pass `context: 'internal'` when
  retrieving application-internal prompt templates.

### Build & CI

- Bumped the `gem_hadar` development dependency constraint to `>= 2.27.2`.

### Testing
- Updated spec mocks in `collection_search_spec.rb`,
  `search_knowledge_spec.rb`, `web_searching_spec.rb`, and
  `execute_grep_spec.rb` to reflect the new `context: 'internal'` keyword
  argument and updated grep command strings.

## 2026-11-23 v0.0.149

### Improvements

- Replaced metaprogrammed JSON column handling with
  `OllamaChat::Database::GenericObject` and the `JSONColumns#json_column`
  concern to prevent `JSON::GeneratorError` under `json` 3.x by enforcing
  symbol-keyed access.
- Migrated `Session` (`trigger`, `model_options`, `tools_default_enabled`),
  `Prompt` (`metadata`), `Favourite` (`metadata`), `ModelOptions` (`options`),
  and `Collection` (`patterns`) to the new `:json_go` serialization format.
- Updated trigger access patterns to use `each_pair` throughout
  `collection_search`, `session`, `information`, and `personae_management`.
- Coerced symbol-keyed collection names to `String` in `edit_session_trigger`
  to prevent leakage into the `SearchUI` chooser prefill.
- Refactored `model_handling` to use `to_h` instead of
  `ask_and_send(:symbolize_keys_recursive)` for model options comparison and
  display.
- Updated `favourite` model specs to expect `GenericObject` return types for
  metadata.
- Updated `personae_management` and `session_management` specs to use `each_pair` for trigger assertions.

### Build & CI

- Bumped `gem_hadar` development dependency to **>= 2.27.1**.
- Bumped `valkey` Docker image from **9.0.1** to **9.1.4** to address security
  vulnerabilities (GHSA-f4q9-j22m-xqq9, CVE-2026-130822) and bug fixes.
- Updated GitHub Actions in `static.yml`: `actions/checkout` to **v7**,
  `actions/configure-pages` to **v6**, `actions/upload-pages-artifact` to
  **v5**, `actions/deploy-pages` to **v5**, and `ruby-version` to **4.0**.

### Testing

- Added specs for `GenericObject` covering JSON load shapes, `each_pair` key
  types, and round-trip serialization.
- Added specs for `JSONColumns` reader, writer, and persistence round-trip.
- Updated `favourite` model specs to verify `GenericObject` deserialization and
  merge behavior.
- Updated `personae_management` and `session_management` specs to align with
  `GenericObject` trigger access patterns.

### Documentation

- Updated `README.md` to document `memorize` and `forget` tools, Audio/Video
  and YouTube source types for `/input`, and new Power User sections for
  Collections, Persona Memory, and Think Mode.
- Added a Command Reference table to `README.md` covering 17 lesser-documented
  commands.
- Added YARD documentation for `GenericObject`, `JSONColumns`, and various
  constants and methods.
- Fixed YARD `@param` warnings for `excon_logger` and `collection`.
- Restructured `CHANGES.md` for consistent formatting and corrected dependency
  version references.

## 2026-11-21 v0.0.148

### Features
- Display byte and token estimates in file choosers
  (`choose_multiple_filenames` and `choose_filename`) by wrapping
  `Pathname` entries in `SearchUI::Wrapper` with a compact size
  annotation (e.g., `lib/foo.rb (12.4 KB · ~3.5 KT)`).

### Fixes
- Use the graceful `paste_from_clipboard` wrapper instead of
  `perform_paste_from_clipboard` in `/persona import` and `/prompt
  edit` command handlers to prevent unhandled exceptions when the
  clipboard is empty or the paste command is missing.

### Improvements
- Broaden the `json` gem dependency constraint to `>= 2.0, < 4` for
  future compatibility.
- Modernize dependency declarations in the gemspec using string
  interpolation syntax.

### Build & CI
- Upgrade `rubygems_version` dependency to **4.1.0**.
- Increase `gem_hadar` dev dependency minimum to **2.26.1**.

### Testing
- Relax the `choose_filename` spec to capture presented entries and
  assert on their `.value`, decoupling the test from display
  formatting.

## 2026-11-18 v0.0.147

### Improvements
- Added `require 'json/generic_object'` in `lib/ollama_chat.rb` to
  ensure `JSON::GenericObject` is loaded before API response parsing,
  providing a forward-compatibility bridge for the `json` **3.0**
  extraction.

### Build & CI
- Bumped `ollama-ruby` dependency to `~> 1.27`.
- Added `json ~> 2.0` runtime dependency to pin the standard library gem
  to **2.x**.
- Added `json-generic_object >= 0.2.0` runtime dependency to provide
  `JSON::GenericObject` once `json` **3.0** drops it.
- Bumped `gem_hadar` development dependency to `>= 2.24.1`.

## 2026-11-18 v0.0.146

### Features
- Added `/restart` command to reload configuration and continue the
  session.
- Added `compaction.think` configuration option to control thinking mode
  during context compaction; defaults to `'auto'` (delegates to
  `ThinkControl#think`), with `'never'` forcing `false`.
- Introduced `choose_multi` utility for interactive multi-selection with
  `[ALL]`/`[NONE]` sentinels, replacing legacy sentinel-loop pickers
  across the codebase.
- Added `text` field to the `memorize` tool result to echo stored content
  back to the LLM.

### Fixes
- Fixed `NoMethodError` in `ollama-ruby` `Progress` when the server
  transmits `success` before a progress bar exists (cached-model path) by
  bumping dependency to **1.26.4**.
- Resolved ghost-bar clobbering in `ollama_update` pull output by bumping
  `ollama-ruby` to **1.26.3** and `infobar` to **0.16.0**.
- Ensured `infobar.finish` is called on all exit paths in `fetcher.rb`
  (`fetch_url` and `fetch_streaming`) to release saved cursor positions
  and render final frames.
- Cleared `infobar` after message list and last output in
  `message_list.rb` to prevent ghost-bar artifacts before subsequent
  `output.puts` calls.
- Handled invalid UTF-8 bytes in `strip_ansi` by encoding input with
  `invalid: :replace` and `undef: :replace`.
- Prevented stale history entries from surfacing during collection
  incineration confirmation by clearing `Reline::HISTORY` and removing
  prefill.

### Improvements
- Migrated all interactive multi-select pickers (tools, favourites,
  personae, links, conversations, files, models, memory collections) to
  use `choose_multi` for consistent UX and reduced code complexity.
- Replaced `⚪`/`⚫` circle icons with `☑`/`🔳` box glyphs in
  `load_personae` to visually distinguish pick state from favourited
  markers.
- Updated favourite icons from `❤`/`🩶` to `⭐`/`⚫` for better visual
  consistency.
- Silenced `infobar` during parallel embedding in `bulk_embed_sources`
  and added user-visible feedback lines for sequential and parallel embed
  paths.
- Improved `/update all` feedback wording with bold collection names and
  explicit type values.
- Delegated editorial thinking to `ThinkControl` in `compaction.rb`,
  `session_management.rb`, `personae_management.rb`, and
  `prompt_management.rb` to respect global `think_mode` settings.
- Added `think:` value to log data in `chat.rb` `generate` for better
  observability at info level.
- Updated `SearchKnowledge` tool descriptions to guide the model toward
  using natural language queries.
- Simplified `source_modified?` guard in `rag_handling.rb` by removing
  redundant `infobar.puts`.

### Build & CI
- Bumped `ollama-ruby` dependency to **1.26.4**.
- Bumped `documentrix` dependency to **0.8.1** to pick up `ensure
  infobar.finish` fix.
- Bumped `infobar` dependency to **0.16.0**.
- Bumped `search_ui` dependency to **0.4**.
- Bumped `gem_hadar` development dependency to **2.22.1**.
- Removed vim modeline configuration from `Gemfile`.

### Testing
- Updated specs to stub `docs.collection` in `update_collection` tests.
- Converted mock returns in specs from sentinel strings to arrays to
  match new `choose_multi` API.
- Added spec for `/restart` command.
- Updated favourite icon assertions in specs to reflect new `⭐`/`⚫`
  glyphs.

### Documentation
- Updated YARD documentation context to omit `@return void` clauses.

## 2026-11-13 v0.0.145

### Fixes
- Raised the minimum `ollama-ruby` dependency constraint to ensure
  the JSONL streaming buffer fix from **v1.26.1** is present.

### Documentation
- Updated `CHANGES.md` to reflect the new dependency floor.

## 2026-11-12 v0.0.144

### Features
- Add a `c` (choose) option to the missing-model prompt in
  `use_model`, allowing users to select a different model instead of
  only confirming a pull or cancelling.

### Improvements
- Improve the stale context error message in `patch_file` to clarify
  that the issue may be a modified file or an incorrect checksum, and
  instruct the user to re-read the full file to obtain a fresh
  checksum.

## 2026-11-11 v0.0.143

### Fixes
- Scoped `AppState.acknowledge` to a single prompt context to
  prevent clearing drift warnings for unrelated contexts.
- `AppState.acknowledge` now accepts an optional `context:` keyword
  argument to surgically update only specific context hashes.

### Improvements
- `prompt_sync` now passes its `context:` argument to
  `AppState.acknowledge` to clear only the resolved context's nagging
  state.

## 2026-11-11 v0.0.142

### Features
- Added status markers to `choose_prompt_context` to
  indicate drift status: `⚠` when shipped config changed,
  `📌` when drifted but unchanged, none when in sync.
- Updated `list_prompts` to display a trailing `📝` marker
  for user variants, while default prompts remain unmarked.

### Fixes
- Fixed `execute_jira_twg` to replace bare braces in the
  first line of pretty-printed JSON output with
  `(structured result)` to prevent confusing messages.
- Resolved false positives in `prompt_sync` drift detection
  by normalizing trailing newlines on shipped and
  database-stored prompt content.

### Improvements
- Relocated `current_directory` from static to dynamic
  runtime information values to maintain a byte-stable
  system prompt prefix across repository switches.
- Extracted drift and orphan computation logic into a
  private `context_drift` method and added
  `context_shipped_changed?` to share code paths between
  the prompt chooser and `prompt_sync`.
- Added `ensure_trailing_newline` to `prompt_handling.rb`
  to canonicalize prompt content for consistent newline
  termination.
- Updated `default_config.yml` to add `**Environment**:`
  and `**State**:` headings to static and dynamic runtime
  info templates.

### Testing
- Added specs for `execute_jira_twg` covering
  pretty-printed JSON, JSON arrays, and plain-text output
  scenarios.
- Updated `choose_prompt_context` spec to mock
  `choose_entry` returning a `SearchUI::Wrapper`.
- Updated spec assertions in `prompt_handling_spec.rb` and
  `prompt_management_spec.rb` to expect canonical trailing
  newlines.

## 2026-11-06 v0.0.141

### Improvements
- Replaced `Tins::Duration#to_s` with `to_human(style: :abbrev)` in
  `follow_chat.rb`, `session_management.rb`, `tool_call_processor.rb`,
  and `generate_image.rb` to produce compact duration strings.
- Replaced hand-rolled duration formatting in `compaction.rb` with
  `Tins::Duration#to_human` for compaction TTS reports.
- Updated `execute_shell` tool description to instruct the LLM to
  separate multi-command scripts with newlines and indentation
  rather than semicolons for improved readability in the review
  editor.
- Added an early-return guard in `ToolCallProcessor#handle` to skip
  tool execution when `chat.tools_support.off?`, emitting a
  `tools_disabled` JSON result per tool call to provide proper
  error feedback to the LLM.

### Fixes
- Set `default: false` for `get_time` and `get_location` tools in
  `default_config.yml`, as these values are already injected into
  runtime info each turn, making default enablement redundant.

### Build & CI
- Bumped `tins` dependency to **~> 1.62** in `Rakefile` and
  `ollama_chat.gemspec`.

### Testing
- Added a spec example in `tool_call_processor_spec.rb` verifying
  that `#handle` returns the expected `tools_disabled` error and
  message when tool support is disabled.

## 2026-11-02 v0.0.140

### Improvements
- In `ExecuteShell`, pressing `C-c` at the `📝 Instructions:` prompt now
  re-prompts the user for the y/n/i/a/d choice instead of submitting a
  blank instruction.
- Updated the instruction prompt in `ExecuteShell` to display a `(C-c ⇨
  cancel)` escape hint.
- Extracted the confirmation gate logic in `ToolCallProcessor` into a
  private `confirm_tool` method, returning a `[confirmed, resolve]`
  tuple to simplify the `handle` method.
- Accept Invidious instance URLs for video transcripts. `fetch_video_info`
  now delegates ID extraction to `extract_video_id`, which supports
  standard YouTube URLs and watch, embed, and shorts paths on the
  configured Invidious instance via `invidious_pattern`.

### Testing
- Added a spec context verifying that an Invidious instance watch URL
  correctly extracts the video ID and produces a transcript.

## 2026-10-30 v0.0.139

### Features
- Added terminal table wrapping for `/help` and `/session list` output. New private methods `wrap_table_rows` and `table_column_budgets` in `OllamaChat::KramdownANSI` compute per-column width budgets and wrap cell content to fit within a configurable percentage of the terminal width.
- Updated `help_message` and `list_sessions` to collect rows into arrays and route them through `wrap_table_rows`, removing manual truncation and heading assignment.

### Fixes
- Fixed a `TypeError` in `Collection.sync` when `chat.documents.collections` yielded no collections by using `.to_a` instead of relying on `Tins::NullClass#to_ary`.
- Improved error handling in `fetch_source` for `OllamaChat::HTTPError` by adding a dedicated rescue clause that logs a warning without a backtrace and stamps `response_status` and `response_reason` onto the `ResponseMetadata.failed` IO.
- Added a non-2xx HTTP status guard in the `get_url` tool to short-circuit processing before document policy dispatch, returning the raw body and a status message instead of feeding error pages to the summarizer.

### Improvements
- Updated the compaction voice report to format context fill percentages as rounded integers with the unit "percent" for grammatical completeness.
- Moved `configure_kramdown_ansi_styles` to a private method in `OllamaChat::KramdownANSI`.
- Expanded YARD documentation for `OllamaChat::KramdownANSI` to describe styling, parsing, and table wrapping concerns.

### Build & CI
- Bumped `kramdown-ansi` dependency from `~> 0.7` to `~> 0.9` in `Rakefile` and `ollama_chat.gemspec`.

### Testing
- Updated `compaction_spec.rb` to expect rounded integer percentages in the spoken compaction report.
- Updated `kramdown_ansi_spec.rb` to use a real `OllamaChat::Chat` instance instead of a double and added examples for `wrap_table_rows` and `table_column_budgets`.
- Updated `get_url_spec.rb` to stub `response_status: nil` on `SourceIO` doubles and added a spec verifying that non-200 statuses skip summarization and import.

### Documentation
- Expanded module documentation in `kramdown_ansi.rb` to describe the three concerns: styling, parsing, and table wrapping.

## 2026-10-28 v0.0.138

### Breaking
- `OllamaChat::Utils::AnalyzeDirectory` now returns a `Hash` with `:height` and
  `:entries` keys instead of a bare `Array`.
- `AnalyzeDirectory` entry hashes no longer include `:type` or `:name` keys;
  directories are identified by a trailing `/` in `:path`.
- `LinksSet` now supports the `<<` insertion idiom via an alias, standardizing
  how links are added to the collection.

### Features
- Added `OllamaChat::Utils::Redact` module with `redact_password` to mask
  credentials in URLs for user-facing display.
- `memory_restore` now deduplicates entries by checking existing tags before
  adding records, reporting the number of skipped duplicates.

### Fixes
- `use_model` now raises `OllamaChat::UnknownModelError` if the previous model
  is missing or blank after a cancelled pull, preventing stale metadata from
  being returned.
- `update_collection` now uses `Set` for the `seen` variable, resolving a
  latent `NoMethodError` when upstream yields a `Set`.
- Corrected the error message in `pull_model_unless_present` to reference the
  `model` parameter instead of the potentially stale `@model` instance
  variable.

### Improvements
- Applied password redaction to all user-visible URL displays, including
  `Chat#inspect`, `Dialog#connect_message`, `Information#info_rag`,
  `Information#print_welcome`, `Tools::Browse#execute`,
  `Tools::GenerateImage#execute`, and `Fetcher.get`.
- Standardized `Set` insertion to use the `<<` idiom across
  `conversation.rb`, `http_handling.rb`, `rag_handling.rb`,
  `generate_image.rb`, and `web_searching.rb`.
- `AnalyzeDirectory` now omits the `:children` key from directory entries when
  the array is empty, both during build and pruning.

### Build & CI
- Added `lib/ollama_chat/utils/redact.rb` to the gemspec file list.

### Testing
- Updated `analyze_directory_spec.rb`, `parsing_spec.rb`, and
  `list_directory_spec.rb` to assert the new `AnalyzeDirectory` return
  structure.
- Added specs for `redact_password` covering `URI`/`String` inputs, passthrough
  for URLs without passwords, and non-mutation of the original object.
- Added specs for `memory_restore` deduplication logic, covering partial and
  full skip scenarios.
- Updated `web_searching_spec.rb` to expect `<<` instead of `add` for link
  insertion.

### Documentation
- Updated `execute_grep` tool description to explicitly state that the regex
  runs against file contents.
- Updated YARD documentation for `AnalyzeDirectory` to reflect the new return
  value structure.

## 2026-10-23 v0.0.137

### Fixes
- Fixed a double-scheme bug in `OC::URL` default generation by delegating to `Ollama.base_url`, ensuring correct handling of `HOST` values that already include `http://` or `https://`.
- Prevented deletion of the `default` collection in `delete_collection`, returning a warning feedback instead.
- Reset `session.current_collection` to `'default'` when the active collection is deleted.

### Improvements
- Ensured the `default` collection row always exists in the database by unioning it with `chat.documents.collections` during `Collection.sync`.
- Removed four vestigial `refresh_system_prompt` calls from `create_collection`, `edit_collection`, `rename_collection`, and `delete_collection`, as collection data no longer interpolates into the system prompt.

### Build & CI
- Updated `ollama-ruby` dependency from **1.25** to **1.26**.
- Updated `kramdown-ansi` dependency from **~> 0.6** to **~> 0.7**.
- Updated `gem_hadar` development dependency from **2.20.1** to **2.21.0**.

### Testing
- Added specs for `delete_collection` to verify refusal to delete the `default` collection, resetting `current_collection` when the active collection is deleted, and leaving `current_collection` unchanged for non-active collections.

### Documentation
- Updated YARD documentation for `refresh_system_prompt` to accurately reflect the placeholders used (`persona`, `persona_name`, `runtime_info`).

## 2026-10-21 v0.0.136

### Features
- Added `always-allow` and `direct` modes to the `execute_shell` tool, allowing users to remember command approvals for the session.
- Extended the `execute_shell` confirmation prompt to include `a` and `d` options.
- Added a `machine` key to the static runtime information, injecting a compact host description into the system prompt.
- Introduced a new `OC::FASTFETCH` configuration option to resolve the `fastfetch` executable path.
- Added a `fastfetch-profile.jsonc` configuration file to define the modules used for the machine profile.

### Fixes
- Updated the `kramdown_ansi` table separator spec to use pipe-bounded syntax to align with `kramdown-ansi` **0.6** requirements.
- Renamed the `/last` command option from `-p` to `-d` for consistency with the `execute_shell` direct mode flag.

### Improvements
- Refactored `execute_shell` output display to use a shared `write_output` helper for both pager and direct output paths.
- Updated the `execute_shell` tool description to document the new `always-allow` and `direct` options.

### Build & CI
- Updated the `kramdown-ansi` dependency constraint from **0.5** to **0.6** in `Rakefile` and `ollama_chat.gemspec`.
- Added `lib/ollama_chat/ollama_chat_config/fastfetch-profile.jsonc` to the gemspec files list.
- Added `git config --global --add safe.directory /work` to the CI test script in `.all_images.yml`.

### Testing
- Added four new specs for `execute_shell` covering `always-allow` and `direct` mode behaviors, including repeat execution and command differentiation.
- Updated `commands_spec.rb` to reflect the rename of the `/last` command option from `-p` to `-d`.
- Added a `before` block in `execute_shell_spec.rb` to clear the `always_allowed` hash and prevent cross-spec contamination.

## 2026-10-19 v0.0.135

### Features
- Introduced `OllamaChat::ModelHandling::ModelCache` to manage model metadata
  and sizes with two-tier storage and lazy registration.
- Added a `-r` flag to the `/model change` command to flush the model cache.
- Added `OllamaChat::ToolCallProcessor` to encapsulate the tool call
  lifecycle, including execution and result storage.
- Enabled searching sessions by ID in the session chooser.

### Fixes
- Rescued `Ollama::Errors::BadRequestError` in `model_present?` to prevent
  unhandled exceptions for model names rejected by the server.
- Fixed persona leakage in new sessions by using `config.persona&.default_name`
  instead of the current session's persona.
- Synchronized session triggers with the active persona via `sync_trigger` to
  ensure triggers are correctly rekeyed or cleared on persona changes.

### Improvements
- Refactored `model_present?` to use `ModelCache` instead of an inline hash.
- Updated `choose_model` to skip the `all_models` API call if the requested
  model is already confirmed present.
- Renamed the prompt context for report templates from `session` to `report`.
- Renamed `OllamaChat::Database::SessionLocking` to
  `OllamaChat::Database::RowLocking` and removed the `chat:` keyword argument
  from `lock?`.
- Replaced `Kramdown::ANSI::Width` prefixes with bare `truncate` and `wrap`
  calls where ANSI sequences are not present.
- Truncated session names in the `/sessions` list to fit terminal width.
- Decoupled `model_with_size` from the `Ollama::Tag` shape to accept model
  name and size directly.

### Build & CI
- Updated the `gem_hadar` development dependency to **2.20.1**.

### Testing
- Added `model_cache_spec.rb` covering cache operations and isolation.
- Added `personae_management_spec.rb` covering `sync_trigger` transitions.
- Added `tool_call_processor_spec.rb` covering `drain`, `clear!`, and result
  storage.
- Updated `commands_spec.rb` to test the `-r` flag for `/model change`.
- Updated `session_management_spec.rb` to verify persona and trigger
  behavior.
- Removed `handle_tool_call_results?` tests as the method was moved to
  `ToolCallProcessor`.

## 2026-10-17 v0.0.134

### Build & CI
- Removed the local path dependency on the `ollama-ruby` gem
  from the `Gemfile`.

## 2026-10-17 v0.0.133

### Features
- Added `context_manifest` toggle for session-level manifest
  mode in `context_spook` output.
- Added `-M` and `~M` flags to `/input` to override the manifest
  setting.

### Fixes
- Fixed a `NoMethodError` in `use_model` when
  `@model_metadata` is `nil` by using safe navigation.
- Prevented spurious newlines in `parsing.rb` by checking
  `parse_png` result with `.full?` before `concat`.
- Fixed trigger key type mismatch in `session_apply` by
  stringifying keys recursively.
- Updated `plain` in `context_usage.rb` to return `'n/a'`
  instead of `nil` when context length is unavailable.

### Build & CI
- Updated `ollama-ruby` dependency constraint to `~> 1.25`.
- Updated `context_spook` dependency constraint to `~> 1.7`.

### Testing
- Added specs for `-M` and `~M` manifest override flags.
- Strengthened trigger configuration assertions in
  `session_management_spec.rb` to verify string keys.
- Updated context usage specs to assert `'n/a'` return value.

### Documentation
- Corrected YARD documentation for `check` option in
  `path_validator.rb`.

## 2026-10-12 v0.0.132

### Breaking
- `clear_whole_collection` replaces the y/n `confirm?` with an `ask?`
  prompt requiring the user to type the full collection name
- `collection` now returns `@documents.collection.to_s`, making the
  return type strictly `[String]`

### Features
- `feedback` gains a `timeout:` kwarg that prompts "press any key to
  continue" to prevent messages from flashing by
- `clear_tag_records` and `clear_collection_sources` pass `timeout: 3`

### Fixes
- `dialog.rb` adds `IOError` to the `STDIN.raw` exception rescue list

### Improvements
- Log messages for `clear_whole_collection` include `target.inspect`
  for better greppability

### Build & CI
- Updated the `tins` runtime dependency constraint from `~> 1.60`,
  `>= 1.60.1` to `~> 1.61`

### Testing
- `commands_spec.rb` updated to expect `'default'` instead of
  `:default` in `rename_collection` and `update_collection`
- `rag_handling_spec.rb` updated with `timeout: 3` in four
  `feedback` expectations
- `rag_handling_spec.rb` rewritten to stub `ask?` and
  `switch_history` instead of the removed `confirm?`

## 2026-10-10 v0.0.131

### Breaking
- Removed the `context_percentage` and `context_gauge` methods from
  `Information`, absorbing their logic into the new `ContextUsage` class.

### Features
- Added a collection chooser to `memory_restore`, allowing users to
  selectively restore collections from a dump file using `[ALL]` and
  `[DONE]` options.
- Added per-letter emojis (🔍, 🧹, 🔙) to menu prompts in `rag_handling.rb`
  to improve the scannability of single-keypress `confirm?` letter menus.

### Improvements
- Extracted ANSI, emoji, and formatting logic from `Information` into a new
  `OllamaChat::ContextUsage` class, providing `colored`, `plain`, `filled`,
  and `percent` API methods.
- Converted `context_usage_colored`, `context_filled`, and
  `context_usage_plain` into delegators on `Information`.
- Updated `MessageList#compact!` to capture `context_usage_colored` for
  both before and after states, ensuring compaction reports render
  threshold-colored values.
- Changed the plain context usage format to be percent-first.
- Updated `session_management.rb` log data to use `context_usage_plain`.
- Updated `asr.rb` to use `%w[]` for `Tempfile.new` arguments and replaced
  `File.size` calls with `wav.size`.
- Updated `memory_dump` to use `Set#sort` directly instead of
  `Set#to_a.sort`.

### Build & CI
- Updated gemspec file lists to include new `context_usage` and
  `context_usage_spec` files.

### Testing
- Added `spec/ollama_chat/context_usage_spec.rb` to verify color
  thresholds, plain formatting, nil-context fallbacks, and fill ratios.
- Updated `asr_spec.rb` to stub the `Tempfile#size` instance method instead
  of the `File.size` class method.
- Migrated spec temporary paths to the new `asset_tmp_path` helper across
  15 spec files, replacing hardcoded paths and PID suffixes.
- Converted `File.write` calls to `Pathname#write` in multiple tool and
  handling specs.
- Updated `prompt_handling_spec` to use `asset_pathname` for file
  operations.
- Adjusted `move_file_spec` assertions to exclude file extensions from
  tokenized basenames.
- Added restore specs for `memory_restore` including chooser stubs, cancel
  cases, and selective-restore scenarios.

## 2026-10-08 v0.0.130

### Features
- Add `line_numbers: true` to the `read_file` tool configuration in
  `default_config.yml`.
- Update `read_file.rb` to fall back to `tool_config.line_numbers?` when
  the model omits the `line_numbers` argument.
- Interpolate the live `line_numbers` default into the tool description
  to ensure it self-documents the current behavior.

### Fixes
- Replace `ask?` with `confirm?` in `rag_handling.rb` for `[v]iew` /
  `[c]lear` prompts to bypass `Reline` and keep command history clean.
- Add `use_pager(force: true)` to the `#clear_collection_sources` view
  branch to fix display artifacts on tall terminals.
- Fix typo in the `read_file` tool description: `linenumbers` to
  `line numbers`.

### Documentation
- Rewrite `confirm?` YARD documentation in `dialog.rb` to clarify the
  two-branch return contract and history-pollution rationale.

### Testing
- Update `rag_handling_spec.rb` to replace `ask?` stubs with
  `confirm?`.
- Refactor `read_file_spec.rb` to extract `let :tool`, update
  `nil`-argument expectations, and add coverage for config-driven
  line number behavior.

## 2026-10-08 v0.0.129

### Features
- The `get_url` tool now supports the `file` scheme and displays the list
  of allowed schemes in its description.
- The `get_url` tool extracts character card metadata from PNG images when
  the `sub_type` is `'png'`.
- The `patch_file` tool supports deletion of line ranges by passing
  `text: null`; omitting the `text` key now raises an error.
- The `update_collection` method prunes stale sources from the vector store
  when collection patterns are shrunk.
- The `/input` help text now clarifies the difference between smart import
  and raw file reading.
- The `/conversation clean` help text now lists the cleanable categories:
  `tools`, `images`, `thinking`, `messages`, `history`, and `links`.

### Fixes
- Replaced `it` with `_1` in the `execute_grep` command template to resolve
  a Ruby **3.3** deprecation warning regarding the implicit block parameter
  in **3.4**.
- Split the pager fallback logic so that `less` receives the `-r` flag while
  `more` does not, ensuring compatibility with GNU `more` on Debian trixie.
- Fixed `URI.parse` errors in `get_url` by encoding spaces as `%20`.
- Corrected swapped prompt references in web searching to ensure
  `prompt(:web_summarize)` is used for the 'summarizing' policy and
  `prompt(:web_import)` for import mode.
- Moved the `prompt(:embed)` call earlier in `source_fetching` to ensure it
  is available for both concurrent and non-concurrent execution paths.

### Improvements
- Renamed the `directory_structure` tool to `list_directory` (class
  `DirectoryStructure` to `ListDirectory`).
- Renamed the `gem_path_lookup` tool to `lookup_gem_path` (class
  `GemPathLookup` to `LookupGemPath`) for verb-first naming consistency.
- Removed the `file_context` tool, as bulk file context is now handled by
  the `/input context` command.
- Reformatted description text in the `get_url` tool for improved
  readability.

### Build & CI
- Bumped the minimum version of the `tins` dependency to **1.60.1**.

### Testing
- Stubbed `Tins::Terminal.columns` and `Tins::Terminal.lines` in
  `spec/spec_helper.rb`.
- Added specs for PNG character card extraction and updated image spec
  doubles to include `sub_type: 'jpeg'`.
- Split `patch_file` specs to distinguish between omitted keys (raises) and
  explicit `nil` (deletes).

## 2026-10-07 v0.0.128

### Breaking
- Removed `/clear` command and `clean` method from `chat.rb`.
- Updated `model_present?`, `pull_model_from_remote`,
  `pull_model_unless_present`, `prepare_model`, and `use_model` to
  require an `ollama:` keyword argument.
- Removed `config` parameter from `eval_template` in
  `execute_grep.rb`, `poll_for_image` in `generate_image.rb`, and
  `check_path` in `run_tests.rb`.
- Refactored `connect_message` in `dialog.rb` to accept `base_url:` and
  `prefix:` keyword arguments; added `connect_message_done` method.

### Features
- Migrated `/clear` functionality to `/conversation clean` with an
  interactive chooser to select specific conversation elements to clear
  such as tools, images, thinking, messages, history, and links.
- Added `OLLAMA_EMBEDDING_URL` configuration to allow embedding
  operations to use a dedicated Ollama server separate from the
  primary chat client.
- Added `/memory dump` and `/memory restore` commands to export and
  import persona memory collections as JSONL files.

### Improvements
- Refactored all tools to use the `tool_config` accessor from
  `Tools::Concern`, replacing 20 direct config call sites across 14
  tool files.
- Removed dead `config` local variables in tool implementations.
- Moved `tool_config` and `allowed_paths` to private methods in
  `Tools::Concern` and added YARD documentation.
- Updated `source_fetching.rb` Semantic splitter to route chunking
  calls to the dedicated embedding Ollama client.
- Added `url` and `model` details to log payloads in
  `collection_search.rb` and `search_knowledge.rb`.
- `/reconnect` command now establishes both primary and embedding
  Ollama connections.

### Documentation
- Documented automatic syntax checking in `patch_file` tool
  description, noting that language-appropriate checks are run
  automatically after patching.
- Updated `README.md` with `OLLAMA_EMBEDDING_URL` environment variable
  documentation.
- Updated YARD prose for `create_memory_collection` to reflect dual-
  input behavior for persona stems and full collection names.

### Testing
- Removed `/clear` specs from `commands_spec.rb` and replaced
  `/conversation clean` specs with delegation tests.
- Added 6 unit examples for `conversation_clean` in
  `conversation_spec.rb` covering various selection and confirmation
  paths.
- Updated `model_handling_spec.rb` call sites to include the new
  `ollama:` keyword argument.
- Added 5 routing specs for `/memory` command in `commands_spec.rb`.
- Added 7 specs for `create_memory_collection`, `memory_dump`, and
  `memory_restore` in `rag_handling_spec.rb`.
- Updated `check_path` mocks in `run_tests_spec.rb` to match the new
  single-argument signature.
- Stubbed `connect_message_done` in `spec_helper.rb`.

## 2026-10-06 v0.0.127

### Features
- Added a `/toggle memory_trigger` switch that controls the session's
  memory trigger state via new `trigger_enabled?` and `set_trigger_enabled`
  session methods.
- Added a `/conversation compact summary` command to display the most recent
  compaction summary, including its narrative and tool-call lookup index.

### Improvements
- Refactored `Switch` to support callable values, wrapping plain values in an
  `adhoc_closure` with a `UNSET` sentinel for read/write disambiguation.
- Added an arity guard to `Switch#initialize` that raises a `TypeError` if a
  callable `value` does not return `-1` from `arity`.
- Added an arity guard to `CombinedSwitch#initialize` requiring the `value`
  proc to be invokable with no arguments (`arity <= 0`).
- Forced the pager for all `execute_shell` output by passing `force: true` to
  `use_pager`, ensuring consistent user experience across tools.
- Moved `set_documents_collection` to a public method in `RAGHandling` and
  updated `chat.rb` and `search_knowledge.rb` to use the new public
  `collection` and `set_documents_collection` accessors.
- Updated `trigger_inject` in `collection_search.rb` to include the surviving
  records array (text, similarity, tags) in the structured log data hash.
- Consolidated duplicate `chat.log` calls in `search_knowledge.rb` and added
  `rerank:` and `pre_rerank:` to the structured data hash.

### Fixes
- Updated `set` methods in `OllamaChat::Switches` to explicitly return `nil`
  for consistent behavior.
- Excluded system-injected messages (`runtime_information`, `trigger_inject`)
  from the compaction summary's `tool_calls` block to focus the index on
  user-initiated tool calls.

### Testing
- Added spec examples for `/toggle memory_trigger` and a new context for
  `Switch` with callable values to verify read isolation, set, and toggle
  behavior.
- Added spec examples for the `/conversation compact summary` command,
  covering both the delegation happy-path and the no-summary fallback.
- Updated `execute_shell` test-mode spec examples to include sample `stdout`
  via `stub_success` to exercise the always-active pager path.
- Updated `search_knowledge` specs to mock the new `chat.collection` and
  `chat.set_documents_collection` methods instead of the previous
  `documents.collection` interface.

### Documentation
- Added YARD documentation for `Switch#adhoc_closure`, the `memory_trigger`
  reader, and the new `:memory_trigger` switch.
- Added `@raise [TypeError]` tags to `Switch#initialize` and
  `CombinedSwitch#initialize`.
- Expanded `@param value` YARD documentation for `CombinedSwitch` to clarify
  arity requirements for callable values.

## 2026-10-05 v0.0.126

### Breaking

- Refactored the tool registry to store classes instead of instances,
  requiring `Concern#initialize(chat)` to inject the session reference;
  tools now access configuration via `self.chat` rather than
  `opts[:chat]`.

- Removed the confirmation prompt from `/conversation compact`;
  compaction now runs immediately without user interaction.

- Split `/collection clear` so the bare command clears the entire
  collection, while the new `clear tags` subcommand handles tag-based
  deletion.

- Renamed `set_current_collection` to `set_documents_collection` in
  `RAGHandling`, `SessionManagement`, and related specifications.

### Features

- Added `update` keyword argument to the `memorize` tool to replace
  existing memory entries by their ISO timestamp tag.

- Added `clear sources` subcommand to `/collection` to remove sources
  from a collection using a source-to-tags browser.

- Added `-r` flag to `/compose` to pre-fill the editor with a
  blockquoted version of the last assistant reply.

- Added `use_pager(force:)` keyword to bypass line-count thresholds
  and invoke the pager regardless of output size.

### Improvements

- Moved path allowlists from static runtime information to tool
  parameter descriptions, injecting specific allowed directories into
  `delete_file`, `move_file`, `patch_file`, `read_file`, and
  `write_file`.

- Relocated `collection_descriptions` from `Information` to
  `RAGHandling` and migrated runtime information formatting to use
  `named_placeholders_interpolate`.

- Enhanced the `forget` tool to return `forgotten_text` in the JSON
  response and include a text snippet in the human-readable message.

- Enriched the `search_knowledge` tool description with available
  collections and the current default collection.

- Implemented a two-level tag-to-source browser for
  `clear_collection_tags` and a source-to-tags browser for
  `clear_collection_sources`.

- Auto-derive the session memory trigger from the persona name during
  `session_apply` and extracted `create_memory_collection` into
  `RAGHandling` as the canonical entry point.

- Stripped ANSI codes from `run_tests` captured output using
  `OllamaChat::Utils::StripANSI` to ensure monochrome tool responses.

- Logged the full `edits` array in `patch_file` info payloads instead
  of only the edit count.

- Documented bottom-up edit order in `patch_file` to prevent models
  from incorrectly compensating for line shifts.

- Included `persona_name` in the default system prompt template.

- Advertise the `C-u` shortcut in the session prompt to generate a
  random session name.

### Fixes

- Used a regular expression for trailing newline removal in pager
  views to improve compatibility with older Ruby versions.

### Build & CI

- Bumped the minimum `documentrix` dependency to **0.8.0** in the
  `Rakefile` and `ollama_chat.gemspec` to support the new
  `records(tags:, sources:)` API.

### Testing

- Migrated all tool specifications to use
  `described_class.new(chat)` and updated execution calls to omit the
  `chat:` keyword argument.

## 2026-10-03 v0.0.125

### Breaking
- Changed `SessionLocking#lock?` to accept a required `chat:` keyword argument, requiring all internal callers to explicitly pass the chat instance.

### Features
- Added session-scoped trigger injection with a new `trigger` JSON column on sessions and an interactive `/session trigger edit` command.
- Introduced `CollectionSearch#trigger_inject` to automatically search, rerank, and inject relevant collection snippets as context during chat.
- Added new prompt contexts for `rerank`, `snippets_retrieval`, and `snippets_trigger` to support differentiated retrieval behaviors.
- Extracted `runtime_information_inject` into `information.rb` and added `persona_name` to the system persona prompt.

### Fixes
- Updated spec expectations for `SessionLocking#lock?`, `parsing`, and `source_fetching` to use Ruby 3.1+ hash shorthand syntax.
- Replaced an unreachable rescue path test in `resolve_tag_spec.rb` with a test verifying handling of non-existent tagged files.
- Updated `search_knowledge_spec.rb` for new prompt names, `collection` blocks, and `tags_set` double expectations.
- Corrected `compaction_spec.rb` regex to match the new `Tins::Duration` formatting output.

### Improvements
- Updated `search_knowledge.rb` to use database-backed prompts for snippet retrieval and added collection metadata to tool results.
- Changed `TagResult` from `Data.define` to `Struct.new` to support mutable fields.
- Replaced instance variable access with `embedding` accessor across `information`, `source_fetching`, and `web_searching` modules.
- Added `∅` fallback display for empty collection patterns in stats and improved logging for embedding and rerank operations.
- Updated compaction voice timing to use `Tins::Duration#format` for human-readable output.
- Reordered flag strings in `bin/ollama_chat_log` for better `Tins::GO` compatibility.

### Build & CI
- Bumped `tins` dependency from `~> **1.58**` to `~> **1.60**` to support unpadded duration formatting directives.

### Testing
- Added `command_concern_spec.rb` with coverage for `help_message`, `command_completions`, and `Command` class methods.
- Added command dispatch specs for `/paste`, `/last`, `/regenerate`, `/prompt delete`, `/web`, and `/character` variations.
- Added `collection_search_spec.rb` covering the full `#trigger_inject` flow including success and failure cases.
- Added `edit_session_trigger` specs in `session_management_spec.rb` for new, update, and switch scenarios.

## 2026-10-02 v0.0.124

### Features
- Added `OllamaChat::Feedback` module to replace raw `STDOUT.puts` and
  `STDERR.puts` calls with typed, testable system notifications.
- Added `memorize` and `forget` tools for managing timestamped memory
  entries in per-persona Documentrix collections.
- Added `/collection query` subcommand to search collections with optional
  edit and rerank flags.
- Added `/config env` subcommand to display the Ollama Chat environment
  variable tree.
- Added `-v` flag to `/last` to voice previous assistant messages.
- Extracted `OllamaChat::CollectionSearch` module to provide shared
  `find_document_records` and `rerank_records` methods.
- Added `refresh_system_prompt` method to re-interpolate the system prompt
  with fresh values after collection mutations.
- Added voice announcement to the compaction report including context fill
  ratios and duration.
- Added `Speaker#wait_for_speaker` method to block until the background
  speaker thread completes.
- Allowed naming new sessions via `choose_session` by threading an optional
  `name:` keyword through `new_session`.

### Fixes
- Fixed indentation bug in `model_handling.rb` import/export by changing
  `sub` to `gsub`.
- Guarded source link rendering in `search_knowledge` against `nil` or
  empty `source` values.
- Suppressed `report_on_exception` on `AudioPlayer` background thread.
- Improved new session name generation to handle `nil` cancellation in
  `determine_valid_new_name_for_session`.

### Improvements
- Replaced `str % {…}` with `named_placeholders_interpolate({…})` for DB
  prompt call sites to handle unknown placeholders gracefully.
- Updated `directory_structure` tool description to "File locator" and
  added guidance to prefer it over shell `find` or `ls -R`.
- Routed prompt change feedback through the `chat` instance in
  `app_state.rb` to ensure messages target the active chat session.
- Updated `rerank_records` to accept an optional `prompt_name:` keyword
  argument.
- Logged stored memory text in the `memorize` tool.
- Extracted `context_usage_colored` and `context_percentage` helpers to
  eliminate duplicated format logic.
- Updated `output_eval_stats` in `follow_chat.rb` to print colored context
  usage.
- Suppressed `report_on_exception` on the `Speaker` background thread.

### Build & CI
- Bumped `const_conf` dependency from `~> **0.3**` to `~> **0.9**`.
- Added `lib/ollama_chat/collection_search.rb` to gemspec file lists.

### Testing
- Added `spec/ollama_chat/speaker_spec.rb` with tests for
  `OllamaChat::Speaker`.
- Switched spec stubs from `allow` to `expect` in multiple spec files to
  enforce required calls.
- Added tests for `speak_last` in `message_list_spec.rb`.
- Added tests for `query_collection` in `commands_spec.rb`.

## 2026-09-25 v0.0.123

### Fixes
- Fixed the `TTS_URL` environment variable reference in the README to
  use the correct `OLLAMA_CHAT_TTS_URL` name.
- Wrapped `@prefix` with `Regexp.quote()` in `RedisCache#unpre` to
  ensure the prefix is always matched as a literal string.
- Fixed typos in the height validation error message for
  `compute_bmi.rb`.
- Updated `multipart_form_data` in `asr.rb` to return only `headers:`,
  `expects:`, and `body:`, preventing extra form fields from leaking
  into Excon request options.

### Improvements
- Reworked `report_conversation` to display the report in the pager
  first, then optionally save it to a file, removing the `save:` keyword
  argument.
- Renamed `report_session` to `generate_conversation_report` to clarify
  its responsibility.
- Reworked `summarize_conversation` to display the summary in the pager
  first, then optionally save it, removing the `save:` keyword argument.
- Added a `cleaned` string prefix to `save_conversation` messages when
  `clean: true` is passed.
- Moved `kramdown_markdown_remove` from `flush_buffer` to `enqueue_tts`
  to ensure all TTS enqueue paths are covered, passing the `markdown:`
  keyword argument based on chat settings.
- Added a `markdown:` keyword argument (default `true`) to
  `kramdown_markdown_remove` to allow skipping the `kramdown_ansi_parse`
  step.
- Updated `kramdown_markdown_remove` to strip `\p{Extended_Pictographic}`
  emoji and Unicode box-drawing characters, and to collapse multi-space
  runs and strip leading/trailing whitespace.
- Tightened the `/conversation` command regex and removed the `-f` flag
  from the command dispatch and help text.

### Build & CI
- Removed the `context_spook` development dependency from `Rakefile` and
  `ollama_chat.gemspec`.

### Testing
- Updated specs for the new show-then-save flows in conversation
  reporting and summarization.
- Added specs for emoji removal, box-drawing character handling, and the
  `markdown: false` option in `kramdown_ansi`.
- Updated ASR specs to verify the new multipart form data structure.
- Updated command and session management specs to reflect removed flags
  and renamed methods.

### Documentation
- Added a README section for `/conversation compact` detailing token-aware
  compaction and a three-step context escalation ladder.
- Updated the README to document `execute_shell`, `execute_jira_twg`, and
  `lookup_group` tools.
- Added README sections for Speech Services (ASR), Audio Playback, and
  Invidious (YouTube Proxy) configuration.
- Added an explanatory comment block to `eval_template` in
  `execute_grep.rb` clarifying template interpolation.
- Updated README sections to reflect the new conversation reporting and
  summarization workflows.

## 2026-09-25 v0.0.122

### Breaking
- Removed the `THINK_MODE_STATES` constant and replaced it with a
  `think_mode_states` method.
- Added a required `chat:` keyword argument to `OllamaChat::ASR.transcribe`,
  `OllamaChat::TTS.voices`, `TTS#fetch_tts`, and voice selector setup.
- Changed the prompt chooser sort order to sort by `use_count` descending.

### Features
- Added per-model thinking-state support via the `/api/show` endpoint,
  including `normalize_think_state` and `ModelMetadata` updates.
- Added `OllamaChat::Invidious` to fetch YouTube video metadata and
  transcripts from an Invidious companion instance.
- Added `HTTPHandling#request_url_response` to consolidate HTTP request
  handling and `Fetcher` middleware management.
- Added `OllamaChat::Speaker` concern for one-shot voice notifications and
  `Chat#speak` facade.
- Added `OllamaChat::ASR` client for audio and video transcription via
  `audio.cpp`.
- Added audio and video support to the `get_url` tool, including a
  `language` parameter for transcription hints.
- Added `reset_prompt_count` and `/prompt reset count` command to reset
  prompt usage counters.
- Added `instruction` parameter to the `get_url` tool and `-i` flag to the
  `/input` command for focused summarization.
- Added config-driven `persona.default_name` support for new sessions.

### Improvements
- Improved error handling in `OllamaChat::ASR` to detect missing executables
  and provide specific error messages.
- Updated YARD documentation in `session.rb`, `state_selectors.rb`, and
  `think_control.rb` to reference `Chat#think_mode_states`.
- Added `require 'ollama_chat/utils/utf8_converter'` to
  `png_metadata_extractor.rb`.
- Reorganized `require` statements in `lib/ollama_chat/utils.rb`
  alphabetically.

### Fixes
- Fixed pager spec to use `allow` instead of `expect` for terminal stubs and
  removed TTY guard.

### Build & CI
- Added `ffmpeg` to the CI Docker image.
- Added `nokogiri` dependency.
- Bumped `tins` dependency to `~> 1.58`.

### Testing
- Added specs for think-mode clamping, `Invidious` video fetching,
  `HTTPHandling`, ASR transcription, audio/video parsing, and prompt
  management commands.

### Documentation
- Updated `ollama_chat` description in the README to be more concise and
  user-focused.

## 2026-09-18 v0.0.121

### Fixes
- Added `**_kwargs` splat to `Say.voices` to prevent
  `ArgumentError` when the TTS state selector forwards keyword
  arguments

## 2026-09-18 v0.0.120

### Features
- Added `OllamaChat::TTS` for text-to-speech synthesis using an
  `audio.cpp` backend, featuring parallel worker threads, ordered
  playback via `OrderedQueue`, RIFF-header stripping, and
  config-driven streaming.
- Added `OllamaChat::Utils::AudioPlayer` to stream raw PCM data to
  `ffplay`, utilizing a background thread and silence injection to
  prevent EOF hangs.
- Added `OllamaChat::Utils::OrderedQueue`, a thread-safe min-heap
  using `Mutex` and `ConditionVariable` for prioritized item
  retrieval.
- Added `OllamaChat::Utils::ExconLogger` to route `Excon` log calls
  through `chat.log(:debug)`.
- Added `KramdownANSI#kramdown_markdown_remove` to strip markdown
  formatting to plain text for TTS playback.
- Added `TTS_URL` (required, sensitive, URI-decoded) and
  `AUDIO_PLAYER_CONFIG` (JSON: `command`, `frequency`, `bits`,
  `pause`) to `OC`, enabling `ConstConf::JSONPlugin`.
- Configured `default_config.yml` to default `voice.handler` to
  `OllamaChat::TTS`, with settings for `model: 'chatterbox'` and
  `stream: { enabled: false, format: 'audio' }`.
- Added `include_hidden` keyword argument to `generate_structure` and
  `recurse_generate_structure` in `analyze_directory.rb` to optionally
  include dotfiles, and fixed recursive calls to forward the flag.
- Added `include_hidden` boolean parameter to the
  `directory_structure` tool definition and pass-through in `execute`.

### Improvements
- Updated `parsing.rb` to always pass `include_hidden: true` for
  directory references, ensuring dotfiles are included regardless of
  the path prefix.
- Updated `state_selectors.rb` to use a single `ask_and_send(:voices,
  model:)` call with an `Array()` guard for voice listing.
- Switched `generate_image.rb` to use `Excon.new(url, logger:)` with
  `ExconLogger` for consistent logging.
- Removed redundant `syntax_check` key from the JSON response in
  `patch_file.rb`.

### Build & CI
- Bumped `tins` dependency to **~> 1.57** in `Rakefile` and gemspec to
  support keyword arguments for `ask_and_send`.

### Testing
- Added specs for `OllamaChat::TTS`, `OllamaChat::Utils::AudioPlayer`,
  `OllamaChat::Utils::ExconLogger`, and
  `OllamaChat::Utils::OrderedQueue`.
- Added tests for `include_hidden` functionality in
  `analyze_directory_spec.rb`, `directory_structure_spec.rb`, and
  `parsing_spec.rb`.
- Migrated existing specs from `chat.send` to `chat.expose`.

### Documentation
- Added an External Dependencies section to `README.md` detailing
  per-executable requirements, install instructions, and `TTS_URL`
  configuration.
- Added YARD documentation for `include_hidden` parameter in
  `analyze_directory.rb`.

## 2026-09-14 v0.0.119

### Features
- Added `bulk_embed_sources` to `source_fetching.rb` using a `Tins::Limited` bounded thread pool with a `Mutex`-guarded results array to enable parallel embedding via `concurrency: 3` in `default_config.yml`.
- Configured Ollama server options with `num_batch: 2048` and increased `batch_size` to `500` in `default_config.yml` to speed up embedding generation.

### Fixes
- Passed `/\b/` as the word-boundary argument to `matcher.similar` in `chooser.rb` to filter out partial-word hits and improve ranked results for model names containing separators.
- Reordered statements in `context_spook` to prevent `STDOUT.puts` from clobbering the implicit return value, ensuring the method returns the serialized context instead of `nil`.
- Restored `@session` to the previous session and re-acquired its lock on session switch failure, while also adding `except_id` to `choose_session` to prevent re-selecting the current session.

### Improvements
- Updated `duplicate_session` to use a direct `session.lock` call instead of a defensive check, as a freshly duplicated session is never locked.
- Replaced `STDOUT.puts` with `infobar.puts` in `embed_source` to prevent raw output from clobbering the progress bar in concurrent workers.
- Refactored `commands.rb` and `rag_handling.rb` to collect sources into a single Hash and issue one `bulk_embed_sources` call, replacing sequential embedding loops.

### Build & CI
- Updated `documentrix` minimum version to **0.7.0** in `Rakefile` and `ollama_chat.gemspec` to support improved embedding speed.

### Testing
- Updated `commands_spec.rb` to stub `bulk_embed_sources` returning an array.
- Added a regression spec in `input_content_spec.rb` asserting that `context_spook` returns a non-blank `String` containing the ingested file path.

## 2026-09-05 v0.0.118

### Features
- Added a `session.standup` prompt template to define a structured
  end-of-session report.
- Added a `prompts.system.report` system prompt for neutral writer-style
  document generation in session reports.
- Added a `words` parameter to the `get_url` tool to control the length of
  the generated summary.

### Fixes
- Fixed `get_url` summarization to invoke the LLM via `generate`, ensuring
  an actual summary is produced rather than returning the raw prompt.
- Prevented spinner output from being garbled by switching from
  `STDOUT.puts` to `infobar.puts` in `summarize_source`.
- Fixed `prompt_management.rb` to invoke the editor only when suggestions
  are present.

### Improvements
- Improved the prompt drift notification in `app_state.rb#seed` to suggest
  running `/prompt sync` and confirm with a clear y/n prompt.
- Replaced literal warning emojis with Unicode escape sequences for
  consistent terminal rendering and introduced `Term::ANSIColor` for bold
  text.
- Moved the compaction system prompt from `prompts.compaction.system` to
  `prompts.system.compaction` and updated `compaction.rb` to resolve it
  accordingly.
- Updated `session_management.rb#report_session` to pass the system prompt
  and enable thinking mode when generating reports.
- Added `Infobar.busy` spinners with descriptive labels to LLM `generate`
  calls in `personae_management.rb`, `prompt_management.rb`, and
  `session_management.rb`.

### Testing
- Updated `compaction_spec.rb` to resolve templates from
  `chat.config.prompts.system.compaction`.
- Added an expectation for the `:report` prompt in
  `session_management_spec.rb`.
- Updated `get_url_spec.rb` to include the `words` parameter in test
  doubles and added a specific test for forwarding a custom word count.

### Documentation
- Added an "Upgrading" section to the README documenting the post-update
  configuration workflow, including `/config diff` and `/prompt sync`
  usage.

## 2026-09-03 v0.0.117

### Fixes
- Fixed `/favourite` subcommand completion rendering by replacing separate
  `add`/`delete` and type arrays in `complete` with `.product`, ensuring
  each subcommand renders as an explicit pair instead of being
  independently cross-multiplied by `arguments`.

### Features
- Added command categories to help output:
  - Added `category(name)` and `current_category` class methods to
    `command_concern.rb` for tracking the active category during
    registration.
  - Added `category:` keyword to `command` and `Command#initialize` with
    `attr_reader :category`.
  - Reworked `help_message` to sort commands by `[category, name]` and
    insert bold full-width category header rows via `colspan: 4`.
  - Added `extend Term::ANSIColor` to the `included` block for `bold{}`
    access.
  - Replaced `## Section` comments in `commands.rb` with `category
    :Section` calls.
  - Added two new categories: `Models` (`/model`, `/think`) and `Prompts`
    (`/prompt`, `/system`, `/suggest`).
  - Moved session-persisted commands (`/toggle`, `/tools`, `/voice`,
    `/document_policy`, `/context_format`) under `category :Session`.
  - Moved `/change_response` and `/conversation` under `category
    :Conversation`.
  - Reduced `Settings` to app-level commands only (`/config`,
    `/favourite`).

### Improvements
- Made `report_session` a pure generator:
  - Removed `&block` parameter and `block&.(result)` call from
    `report_session`, eliminating the infobar side-effect that caused
    double output.
  - Simplified `report_conversation` to call `report_session(name:)`
    without a block; display logic (pager or file write) is the sole
    consumer of the returned string.
  - Removed `@param block [Proc]` from `report_session` YARD docs.

## 2026-09-03 v0.0.116

### Breaking
- Moved the `summarize` subcommand from `/session` to `/conversation`.
- Removed the `pretty:` keyword argument from `summarize_session` and
  `summarize_conversation`, making markdown formatting the only path.
- Removed `%{message_thinking}` from the `session_summarize` prompt.

### Features
- Added `summarize` and `report` subcommands to `/conversation`.
- Added `summarize_conversation` and `report_conversation` methods to
  `session_management.rb`.
- Added `report_session` method using `messages.compacted_messages` to keep
  interpolated content bounded.
- Added `session.roleplay_story` prompt to `default_config.yml`.
- Added `session.coding_brief` prompt to `default_config.yml`.
- Added `ask_for_filename?` and `should_overwrite?` helpers to `dialog.rb`.
- Added `Status:` line to `collection_stats` in `information.rb`.
- Added status indicators to `list_collections` and `list_tools`.

### Improvements
- Reworked compaction prompt to treat previous summaries as drafts.
- Changed compaction prompt to preserve trailing newlines.
- Widened factuality scope in compaction prompt.
- Wrapped `list_tools` body in `use_pager`.
- Refactored file overwrite checks to use `should_overwrite?`.
- Updated prompt template naming convention in comments.
- Rewrapped few-shot examples to stay within 80 columns.

### Testing
- Added specs for `summarize_conversation`, `report_session`, and
  `report_conversation`.
- Added routing specs for `/conversation summarize` and `/conversation
  report`.
- Updated `chat_spec.rb`, `tool_calling_spec.rb`, and `conversation_spec.rb`
  to match new outputs and behaviors.
- Updated `compaction_spec.rb` assertions for the new draft-rewrite prompt.

### Documentation
- Added YARD documentation for `repair_group_uuids`.
- Added YARD documentation for `ask_for_filename?` and `should_overwrite?`.
- Fixed stale YARD example in `session_management.rb`.

## 2026-09-01 v0.0.115

### Features
- Added `OllamaChat::Tools::ExecuteShell` in `lib/ollama_chat/tools/execute_shell.rb`,
  which executes shell commands via `sh -c` after a mandatory human review
  flow involving an `edit_text` editor review and a `y/n/i` confirm prompt.
- Implemented a `y/n/i` gate in the `execute_shell` tool where `y` executes,
  `n` cancels, and `i` captures user instructions for the LLM to revise the
  command.
- Configured `require_confirmation: false` in `default_config.yml` to skip
  the preflight confirm in `follow_chat`, relying on the in-tool `confirm?`
  as the primary safety mechanism.
- Enabled output display via `use_pager` with bold `stdout:`/`stderr:` labels
  and exit codes, with `monochrome: true` (default) stripping ANSI codes
  before returning results to the LLM.
- Standardized error handling for `execute_shell` failure paths (blank
  command, editor abandoned/cleared, user declined, instruct) to raise
  `OllamaChat::ToolFunctionArgumentError`, which is rescued to log and return
  structured JSON including the `command`.
- Added a `summary_template` class method to `execute_shell` for one-liner
  output in `lookup_group` compaction.
- Registered `execute_shell` in `lib/ollama_chat/tools.rb` and configured it
  in `default_config.yml` with `default: false` and
  `result_display_timeout: 10`.
- Introduced `OllamaChat::Utils::StripANSI` module in
  `lib/ollama_chat/utils/strip_ansi.rb` with a regex-based `strip_ansi`
  method handling both SGR and OSC escape sequences.
- Replaced `Term::ANSIColor.uncolor` calls with `strip_ansi` in
  `lib/ollama_chat/tools/execute_shell.rb`, `lib/ollama_chat/commands.rb`
  (`/input` path and default subcommands), and `bin/ollama_chat_send`.

### Testing
- Added 18 spec examples in `spec/ollama_chat/tools/execute_shell_spec.rb`
  covering identity, execution, editor cancel, instruct, monochrome, pager
  display, and `summary_template`.
- Fixed `read_file` and `write_file` spec assertions in `read_file_spec.rb`
  and `write_file_spec.rb` to match the token-first output format (`tokens
  (bytes)`) shipped in **v0.0.114**.

### Build & CI
- Registered `lib/ollama_chat/utils/strip_ansi.rb` in
  `ollama_chat.gemspec` file lists.

## 2026-09-01 v0.0.114

### Features
- Added a context compaction pipeline to summarize older messages,
  including `OllamaChat::Compaction`, `CompactionError`, and the
  `lookup_group` tool for retrieving pre-summary content.
- Introduced configurable syntax checkers for `write_file` and
  `patch_file` tools, supporting Ruby, JavaScript, Python, and Shell.
- Enabled toggling RAG collection availability via a new `enabled` flag,
  filtering disabled collections from search results and system prompts.
- Added monochrome flags (`-m`) to `bin/ollama_chat_send` and the
  `/input` command to strip ANSI color codes from content.
- Implemented per-message token estimation via `token_estimate` in
  `MessageMixin` and `total_tokens` in `MessageList`.
- Added a color-coded context gauge to the session information display.
- Introduced log rotation functionality via `LogRotation.truncate_tail`
  and restructured log configuration in the `LOG` module.

### Fixes
- Resolved a `NoMethodError` in `TagResolver#resolve` by threading the
  chat instance for logging.
- Capped inline directory structure expansion by enforcing a default
  `max_depth` of **1** in parsing.

### Improvements
- Increased `compaction.reserve.ratio` from **0.30** to **0.60** in the
  default configuration.
- Standardized user-facing token and byte output format to `tokens
  (bytes)` across file tools and session management.
- Replaced `Struct.new` with `Data.define` for `ModelMetadata`,
  `Estimate`, and `TagResult`.
- Ensured multi-byte safety by using `bytesize` instead of `size` for
  byte counts in token estimation and content processing.
- Updated `/conversation compact` to use the new `compact_with_retry`
  method.
- Acknowledged prompt state after `/prompt sync` to prevent repeated boot
  drift notifications.
- Reordered `session_title` prompt content to improve generation
  reliability.
- Updated `/config diff` to reload the configuration after displaying
  differences.

### Testing
- Added `compaction_spec.rb`, `concern_spec.rb`, and
  `lookup_group_spec.rb` to cover new compaction and tool logic.
- Extended tool specs with assertions for `summary_template`.
- Added `message_spec.rb` for `token_estimate` and message attributes.
- Included specs for `log_rotation` and `analyze_directory` depth
  handling.

### Documentation
- Updated `README.md` with environment variables for log paths,
  `DIFF_COMMAND`, and various tool configurations.

## 2026-08-25 v0.0.113

### Features
- Removed the `/conversation compact` subcommand stub, including
  its regexp, completion list, help text, handler logic, and
  associated specs.
- Updated the `/config diff` subcommand to call `reload_config`
  after `diff_config`.

### Improvements
- Simplified hash syntax by replacing `text: text` with `text:` in
  `Clipboard#copy_to_clipboard`.
- Simplified hash syntax by replacing `name: name` with `name:` in
  `RAGHandling` collection creation log.
- Cleared the message field in `PatchFile` tool responses by
  returning an empty string for the `message` attribute.
- Removed the unused `collection_descriptions: {}` entry from the
  `embedding:` section in `default_config.yml`.

### Testing
- Added specs for `/config edit`, `/config reload`, and `/config diff`
  in `commands_spec.rb`, verifying the ordered sequence of
  `diff_config` followed by the new `reload_config` for the diff
  command.

## 2026-08-25 v0.0.112

### Features
- Added a `diff` subcommand to the `/config` command to compare
  the current configuration file with the default configuration.

### Improvements
- Extracted the `diff_config` method in `OllamaChat::ConfigHandling`
  to encapsulate diff tool resolution and execution logic.
- Refactored `fix_config` to delegate diff invocation to the new
  `diff_config` method.

### Testing
- Added specs for `diff_config` covering error handling when the
  diff tool is missing and successful execution with a configured tool.

## 2026-08-25 v0.0.111

### Features
- Added `OllamaChat::Tools::ExecuteJiraTwg` tool as a `twg` CLI wrapper.
- Added `OC::OLLAMA::CHAT::TOOLS::JIRA::TWG` configuration constant.
- Added `execute_jira_twg` entry in `default_config.yml`.
- Added two-step tool approval workflow in `FollowChat#handle_tool_calls`.
- Added `session_sync` method to persist session state and re-lock.
- Added `context_usage` method to calculate and format context usage.
- Added context usage gauge in `info_session` output.

### Improvements
- Refactored `FollowChat#handle_tool_calls` to remove redundant branches.
- Simplified `session_close` to delegate to `session_sync`.
- Updated `change_session` to use `session_sync` in `ensure` block.
- Added `session.lock` guarantee in `set_new_session`.
- Refactored context usage logic for maintainability.
- Updated `session_management.rb` logging to use `context_usage`.
- Simplified `self.register_name` in `GemPathLookup`.
- Silenced `which` stderr in all OC config defaults.

### Fixes
- Guarded context ingestion against empty file sets.
- Added safe navigation to `current_context_length`.
- Wrapped `context_usage` to return `nil` when unavailable.

### Testing
- Added specs for `OllamaChat::Tools::ExecuteJiraTwg`.
- Added spec for `session_sync` ordered calls.
- Added specs for `/conversation compact` command.
- Added `api_ps.json` test asset.
- Stubbed `GET /api/ps` in `spec_helper.rb`.
- Updated expected file counts in parsing and directory specs.

### Build & CI
- Updated gemspec file manifest to include new tool and spec files.

## 2026-08-20 v0.0.110

### Features
- Added `/prompt sync` subcommand to detect drift between database
  prompts and shipped defaults, display unified diffs via
  `OC::DIFF_COMMAND`, and offer interactive resolution through
  `OC::DIFF_TOOL`.
- Added `AppState` model with `get` and `set` helpers and a `seed` boot
  check that compares `Digest::SHA256` hashes of default prompts to
  detect drift, prompting user acknowledgment on first run or changes.
- Added `OC::DIFF_COMMAND` setting to configure the unified diff command
  used for prompt synchronization.
- Added `OllamaChat.test_mode` flag to suppress interactive prompts
  during specification runs.

### Fixes
- Updated `web_searching.rb` to store `search_engine` in a local
  variable to avoid redundant method calls.
- Added `session_close` call after successful `clean_messages!`
  execution in `commands.rb`.
- Simplified the stale context error message in `PatchFile` when a
  checksum mismatch is detected.

### Testing
- Updated `web_searching_spec.rb` to use `expect` instead of `allow` for
  message expectations and adjusted call counts to match actual behavior.
- Added seven new spec examples for `prompt_sync` and `show_prompt_diff`
  in `prompt_management_spec.rb`.

### Documentation
- Added YARD `@!attribute` documentation for `test_mode` and
  `test_mode?`.

## 2026-08-18 v0.0.109

### Features
- Added `export_model_options` and `import_model_options` methods to the `/model` command, enabling users to save and restore model profiles to or from a JSON file.
- Introduced the `-p` flag for the `/model options import` command to narrow file search patterns, defaulting to `**/*.json` if not specified.
- Added the `-i` flag to the `/paste` command to read content from standard input instead of the clipboard, with support for the `-e` flag to edit the content before pasting.
- Added `options` metadata to the `/copy`, `/paste`, `/toggle`, and `/model` command definitions to improve command parsing and help text.

### Fixes
- Fixed an infinite retry loop in `kramdown_ansi.rb` by ensuring the `retried` flag persists across `retry` calls within the same method frame.
- Corrected the YARD `@return` documentation for `#info_prompt` in `prompt_management.rb` to accurately reflect that it always returns `self`.

### Improvements
- Refactored session management to extract `set_previous_session_on_change` as a shared private method, ensuring consistent handling of `@previous_session_id` across `set_new_session`, `duplicate_session`, and `change_session`.
- Normalized `context` and `name` arguments in `prompt_handling.rb` to safely handle `Symbol` inputs in SQL queries by converting them to strings.
- Migrated test stubs from `allow` to `expect` across multiple spec files to eliminate false-green tests where stubs were never invoked.

### Testing
- Added comprehensive test coverage for previously untested or under-tested modules, including `Conversation`, `FavouritesManagement`, `RAGHandling`, `PromptHandling`, `PromptManagement`, `SystemPromptManagement`, `ConfigHandling`, `WebSearching`, and `Information`.
- Updated `web_searching_spec.rb` to cover edge cases for `#search_web`, `#web`, and `#manage_links`, and expanded `information_spec.rb` to test `#client`, `#collection_descriptions`, `#user`, and `#infobar_message`.
- Added functional specs for the new model options export and import features, covering export, cancellation, selective import, diff display, and override confirmation.

### Build & CI
- Updated `s.files` and `s.test_files` in `ollama_chat.gemspec` to include new configuration, asset, and test files, ensuring all project resources are correctly bundled.

## 2026-08-15 v0.0.108

### Features
- Added `max` to `THINK_MODE_STATES` in `think_control.rb` to support
  newer Ollama releases (e.g., **0.32.13**).
- Added migration `008_drop_think_mode_constraint.rb` to drop the
  `think_mode` `CHECK` constraint in SQLite.
- Added `require_confirmation: true` to `get_current_weather`, `get_cve`,
  `get_endoflife`, `browse`, `get_jira_issue`, `get_rfc`, and `get_ghr`.
- Introduced `OLLAMA_CHAT::COLLECTION_NAME_REGEXP` in `lib/ollama_chat.rb`
  to enforce safe identifiers.

### Improvements
- Refactored `confirm?` key reads to use `STDIN.raw(min:, time:, intr: true)`
  instead of `stty` commands.
- Updated `confirm?` to print prompts to `output` instead of `STDOUT`.
- Updated confirmation glyphs: `\u2328\uFE0F` to `\u2328`, `☑️` to `\u2611`,
  and `🚫` to `\u{1F6AB}`.
- Scoped `Reline` histories for interactive prompts to distinct
  namespaces, including `:session_name`, `:persona_name`, `:patterns`,
  `:filename`, `:profile_name`, `:collection_name`, and
  `:collection_description`.
- Refactored terminal truncation by moving `truncate_for_terminal` from
  `prepare_last_message` to `last_message_with_user`.
- Added `height:` keyword argument to `last_message_with_user` and
  `display_formatted_terminal_output`.
- Refactored `display_formatted_terminal_output` to use `move_home` and
  `erase_in_display(nil)` instead of `clear_screen` to prevent `tmux`
  flicker.
- Updated `require_confirmation` to `false` for `open_file_in_editor`,
  `paste_into_editor`, and `generate_image`.
- Removed `jq` parsing from `OLLAMA_CHAT_TOOLS_TEST_RUNNER` in `.envrc`.
- Wrapped web search link list output in `use_pager` within
  `OLLAMA_CHAT::WebSearching`.

### Fixes
- Added `rescue` for `Interrupt` and `IRB::Abort` during key reads to
  return `nil` and print `"\u274C\uFE0F"`.
- Fixed `tmux` flicker in vertically split panes by avoiding full-pane
  redraws.
- Fixed `OLLAMA_CHAT::Tools::PatchFile` to explicitly warn against
  redundant tool calls.
- Updated `OLLAMA_CHAT::Chat#initial_collection` to validate names
  against the new `COLLECTION_NAME_REGEXP`.
- Updated `OLLAMA_CHAT::Tools::SearchKnowledge` to raise
  `OLLAMA_CHAT::ToolFunctionArgumentError` on invalid collection
  names.

### Build & CI
- Added `.obsidian` to `.gitignore` and the `GemHadar` `ignore` list in
  `Rakefile`.

### Testing
- Updated `OllamaChat::FollowChat` spec to expect a single string argument
  in `output.print` calls.
- Updated `OllamaChat::SessionManagement` spec to pin `switch_history`
  namespace with `:session_name`.
- Added specs for `OllamaChat::Chat#initial_collection` validation.
- Added spec for invalid collection name handling in
  `OllamaChat::Tools::SearchKnowledge`.

## 2026-08-09 v0.0.107

### Features
- Added `-e` option to `ollama_chat_send` to open input content in the
  configured editor before sending.
- Added `-F` option to `ollama_chat_send` to specify file extension for
  syntax highlighting in the editor.
- Added confirmation prompts to `write_file` for overwriting existing files
  and creating new files in append mode.
- Implemented pluggable voice handler architecture via a new `handler` key
  in the `voice` configuration.

### Improvements
- Refactored voice handling to use a dynamic `voice_handler` method in
  `OllamaChat::Chat`.
- Externalized the suggestion prompt template by adding
  `context_template_suggest` to `default_config.yml`.
- Refactored `OllamaChat::Say.voices` to extract logic from
  `default_config.yml`.

### Fixes
- Reopened `STDIN` from `/dev/tty` during editing to prevent editor warnings.
- Added `.to_s` call on `prompt` results to handle `Sequel::Model` return
  types.
- Raised `OllamaChat::ToolFunctionArgumentError` when file operation
  confirmation is declined.

### Testing
- Updated `spec/ollama_chat/commands_spec.rb` to use explicit `.jsonl`
  extensions for conversation save and load tests.
- Added specs to verify `write_file` confirmation flows.

## 2026-08-06 v0.0.106

### Features
- Added `/model options delete` command to remove saved model
  options profiles.
- Implemented `delete_model_options_profile` in `model_handling.rb`
  to handle profile deletion and default profile resetting.
- Added `/prompt rename` command for renaming prompt templates.
- Implemented `rename_prompt` method in `prompt_management.rb`.
- Added support for shell-style quoting in file pattern arguments
  using `Shellwords.split`.

### Fixes
- Fixed `Prompt#after_destroy` to use fully qualified
  `OllamaChat::Database::Models::Favourite` to resolve scope
  limitations.
- Ensured the `default` profile remains valid by resetting it to an
  empty options hash instead of deleting it.

### Improvements
- Tightened validation for the `/conversation` command to restrict
  filenames to `.json` or `.jsonl` extensions.
- Updated `options` string documentation to include the optional
  `FILENAME` argument and added format hints to help text.
- Added a `suggest` parameter to `choose_profile_for_model` to insert
  specific profiles at the top of selection lists.
- Updated `copy_model_options_profile` to use the source profile as
  the suggested destination.
- Refactored error logging in `OllamaChat::Chat` to use the `log`
  method with `:warn` level instead of direct `STDOUT.puts`.
- Centralized pattern parsing logic by replacing `arg.scan` with
  `extract_patterns` in `commands.rb`.
- Updated context generation in `input_content.rb` to dynamically
  call `to_json` or `to_toon` based on the selected format.
- Wrapped long output strings in `model_handling.rb` for better
  readability.
- Wrapped prompt operations in `switch_history(:prompt)` for
  improved consistency.
- Updated YARD documentation for `extract_patterns` to reflect new
  shell semantics.

## 2026-08-04 v0.0.105

### Breaking
- Removed deprecated CLI flags `-c`, `-C`, `-D`, `-M`, and `-E` in favor of
  interactive management options.

### Features
- Added `OllamaChat::Database::Models::Collection` model and `Sequel`
  migration for persistent RAG collection storage, including an
  `after_destroy` hook to purge corresponding `Documentrix` vector data.
- Introduced interactive `/collection` commands including `new`, `edit`,
  `delete`, and `update all`.
- Added an `options copy` subcommand to the `/model` command, allowing
  users to interactively copy configuration profiles between models.
- Implemented `choose_prompt_context` to allow the `/prompt` command to
  dynamically query and select contexts via a new `-c ?` flag.
- Added `Collection.sync` method to backfill missing database records
  during application startup.

### Improvements
- Enhanced model options matching to check all saved `ModelOptions` profiles
  and display available profiles via pager, offering the ability to switch
  profiles via `choose_profile_for_model`.
- Improved `list_collections` to display descriptions and utilize a pager
  for readability.
- Updated `update_collection` to perform pattern-based delta synchronization
  for new files.
- Renamed `show_session` to `info_session` within the `Commands` module for
  increased verbosity when no subcommand is provided.
- Replaced `.exists?` and `.first` dataset checks with `.present?` in
  `model_handling.rb` and `session_management.rb`.

### Documentation
- Clarified that the `checksum` for the `patch_file` tool must be an 8 hex
  digit long CRC32.
- Added YARD `@!attribute` documentation for `links` and `history` in the
  `Session` model.

### Testing
- Updated test suite to reflect new interactive workflows and removed
  tests for deprecated CLI flags.
- Added specs for the new model options copy command.

## 2026-07-31 v0.0.104

### Features
- Enabled interactive profile creation in `/model options`
  by supporting the `allow_new` keyword argument in
  `choose_profile_for_model` with duplicate validation.

### Breaking
- Renamed the `retrieve_document_snippets` tool to
  `search_knowledge`, requiring updates to configuration and
  model instructions.
- Renamed the `offer_new_session` parameter to `allow_new` in
  `choose_session` and `session_management.rb`.

### Improvements
- Updated tool descriptions and default configuration for
  `search_knowledge` to reference knowledge collections.
- Standardized `/model options` to allow profile creation and
  exit on cancellation, while defaulting to the `default`
  profile for other model commands.

### Testing
- Adjusted test cases in `commands_spec.rb` and
  `search_knowledge_spec.rb` to reflect updated method
  signatures and tool names.

## 2026-07-30 v0.0.103

### Features
- Added `-y` and `-n` flags to the `/toggle` command to explicitly enable
  or disable feature switches like `markdown` and `stream`.
- Added the `-m` flag to the `/model` command to allow interactive model
  selection via `choose_model`.
- Implemented path templating in `run_tests.rb` using `%{path}` to
  inject the test path into the configured runner command.
- Added startup logging to the `start` method in `chat.rb` to record
  client/server versions, URL, user, and config filename.
- Introduced automatic profile resolution via `choose_profile_for_model`
  in `model_handling.rb`, which skips the prompt if only one profile
  exists.

### Improvements
- Optimized the `/model change` command by moving option parsing after
  an early exit for the `change` subcommand.
- Simplified the `/model` command by removing the `-p` flag and relying
  on automatic profile resolution with a fallback to `'default'`.
- Standardized emoji rendering in tmux using Unicode escape sequences
  and Variation Selector-16 across `commands.rb`, `dialog.rb`,
  `favourites_management.rb`, and `information.rb`.
- Refactored `use_model` and related methods in `model_handling.rb` to
  utilize keyword shorthand and accept optional `model_name` arguments.
- Updated the `OLLAMA_CHAT_TOOLS_TEST_RUNNER` environment variable in
  `.envrc` to use JSON output and the `--no-color` flag for `bundle
  exec rspec`.

### Fixes
- Set `OC::OLLAMA::CHAT::TOOLS::JIRA::URL` to `nil` in specs to ensure
  the Jira tool is unconfigured during testing.
- Fixed `prefill_prompt` in `chat.rb` to return the prompt string
  instead of a boolean.

### Build & CI
- Added `spec/ollama_chat/commands_spec.rb` to the file lists in
  `ollama_chat.gemspec`.

### Testing
- Relocated `handle_input` test cases from `chat_spec.rb` to a new
  `commands_spec.rb`.
- Reorganized command specs in `commands_spec.rb` into dedicated
  `describe` blocks for improved navigation.
- Added specs for the new `-y`/`-n` toggle flags and `-m` model
  selection flag.
- Updated parsing specs in `parsing_spec.rb` to conditionally skip
  tests if `gs` or `pandoc` binaries are not present.

## 2026-07-26 v0.0.102

### Features

- Added the `ollama_chat_log` executable to the `Rakefile` and
  `ollama_chat.gemspec`.

## 2026-07-26 v0.0.101

### Features
- Introduced the `clean` subcommand to the `/conversation` command to
  strip tool content, images, and thinking from messages in place.
- Added `OllamaChat::Utils::LogViewer` and the `bin/ollama_chat_log` utility
  for real-time, colorized JSON log tailing with regex filtering.
- Added `estimate_tokens` and `count_messages` helper methods to
  `OllamaChat::Database::Models::Session`.
- Implemented `clean_messages!` in `OllamaChat::MessageList`.
- Updated the `/conversation` command to support the `-c` flag for `save`.

### Fixes
- Replaced `mtime` and `line_count` checks in `patch_file` with a CRC32
  `checksum` to improve file patching integrity.
- Updated `read_file` to conditionally return `checksum` only when full-file
  line numbers are requested, optimizing token usage.
- Refactored `OllamaChat::Logging#log` to use `deep_transform` for payload
  sanitization, handling circular references and non-serializable objects.
- Standardized the `tool: name` variable across 28+ tool classes to ensure
  consistent audit trails.
- Expanded logging coverage for file operations, grep, tests, RAG handling,
  session management, and clipboard operations.
- Split `OllamaChat::FollowChat#eval_stats` into a data extraction method
  `stats_hash` and a separate formatting method.
- Updated `/conversation` to validate paths for `save` and `load`
  subcommands.
- Modified `lib/ollama_chat/tools/patch_file.rb` to validate that `edits` is
  an `Array` and handle `checksum` mismatches.

### Improvements
- Added the `file-tail` gem as a runtime dependency.
- Updated the `gem_hadar` development dependency to require version
  **>= 2.18.0**.

### Testing
- Updated specs for `patch_file`, `read_file`, `log_viewer`, and logging
  expectations.

### Documentation
- Added YARD documentation for `clean_messages!`.
- Updated `README.md` with usage instructions for `ollama_chat_log`.

## 2026-07-23 v0.0.100

### Features
- Added a UUID v7 compatibility shim via `OllamaChat::UUIDV7.generate`
  that uses native `SecureRandom.uuid_v7` for Ruby **3.3**+ and a custom
  RFC 9562 compliant implementation for older versions.
- Added EPUB support using `pandoc` via the `epub_read` method and updated
  `parse_source` to handle `application/epub+zip`.
- Enhanced retrieval precision by prepending source identifiers to document
  chunks in `embed_source`.
- Implemented a JSON formatter in `OllamaChat::Logging` with a `data:`
  keyword argument for structured context, including separate capture of
  backtraces and tool execution details.
- Unified the prompt API using a `context:` keyword argument across
  `prompt`, `each_prompt`, `delete_prompt`, `store_prompt`, and
  `write_prompt`.
- Introduced dynamic context parameters defaulting to `'prompt'` and
  restructured `default_config.yml` to nest prompts under `prompt:`,
  `suggest:`, and `system:`.
- Promoted `/suggest` to a top-level command and simplified the `/system`
  command.
- Introduced `group_uuid` in `OllamaChat::Message` to enable conversation
  grouping, including a `repair_group_uuids` method in
  `OllamaChat::SessionManagement` for legacy data migration.
- Added support for line numbering via the `line_numbers` parameter and
  range extraction using `start_line` and `end_line` in the `read_file`
  tool, now returning total `line_count` and file `mtime` in ISO8601
  format.
- Refactored `patch_file` to support coordinate-based patching via an
  `edits` parameter for targeted line-range replacements, including overlap
  detection and freshness checks using `mtime`.
- Added `base64url` alphabet support to `generate_password` and critical
  security warnings to discourage the use of `eval_ruby` for secret
  generation.
- Added a welcome message upon startup displaying the version, connected
  server version, and URL via `print_welcome`.
- Implemented `OllamaChatQuitError` to handle graceful application
  shutdowns via exception-based control flow.
- Added a `[QUIT-APP]` option to the session chooser after deletion.
- Added current Git SHA details to the runtime information prompt.

### Fixes
- Added error logging to the `rescue` blocks of all tool execution methods.
- Fixed a typo in the Ghostscript error message within `ps_read`.
- Added defensive handling for `JSON.load` results in `model_handling.rb`
  using `.full? || {}` to prevent `nil` propagation.
- Removed implicit fallbacks to the last assistant response in
  `copy_to_clipboard` and `paste_into_editor`, making `text` a required
  parameter.

### Improvements
- Refactored command help strings with emoji prefixes and a more concise,
  scannable multi-line format using heredocs.
- Standardized the creation workflow for prompts and personae with a source
  selection menu offering clipboard, file, or manual input options.
- Optimized `ps_read` by replacing manual read loops with `IO.copy_stream`.
- Centralized Ollama chat request logging through a new `call_ollama_chat`
  wrapper.
- Refactored model option reconfiguration into a dedicated
  `reconfigure_model_options` method in `lib/ollama_chat/model_handling.rb`.
- Refactored namespaced tool call resolution to use regex capture groups
  instead of `File.basename`.

### Build & CI
- Updated dependencies: `ollama-ruby` to **1.23** and `tins` to **1.54**.

### Testing
- Added comprehensive specs for session management covering lifecycle,
  persistence, and state transitions.
- Updated test cases to verify new `line_count` and `mtime` fields in
  `read_file` tool responses.
- Added tests for EPUB parsing, structured logging, and UUID group
  repair logic.

## 2026-07-13 v0.0.99

### Features
- Made `text` a required parameter for the
  `OllamaChat::Tools::CopyToClipboard` tool.

### Fixes
- Updated command regexes to prevent positional
  arguments from starting with a hyphen.
- Added explicit suggestions for `/drop` and
  `/regenerate` in warning messages for last
  message type mismatches.
- Raised `OllamaChat::ToolFunctionArgumentError`
  when `text` is missing in
  `OllamaChat::Tools::CopyToClipboard`.

### Improvements
- Added conditional logging to the `generate` method
  to warn on empty LLM results.
- Implemented guard clauses to abort processing in
  `OllamaChat::PromptManagement` if text or
  generation results are empty.
- Overhauled `suggest_coding` and `suggest_roleplaying`
  prompts in `default_config.yml` to provide more
  detailed and diverse suggestions.
- Adopted Ruby shorthand for keyword arguments in
  `PersonaeManagement`, `PromptManagement`, and
  various spec files.

### Testing
- Updated `OllamaChat::Tools::CopyToClipboard` specs
  to verify argument validation and required `text`
  behavior.

## 2026-07-09 v0.0.98

### Features
- Added a `prefill_prompt` getter and setter to
  `OllamaChat::Chat` to manage prefill state.
- Updated `suggest` to persist results using `self.prefill_prompt`.

### Improvements
- Replaced direct `@prefill_prompt` instance variable access with
  the `self.prefill_prompt` interface in `OllamaChat::Chat`,
  `OllamaChat::Commands`, and `OllamaChat::PersonaeManagement`.
- Enabled paging for the `info` subcommand output in
  `OllamaChat::Commands`.
- Added a confirmation message to the `import` subcommand in
  `OllamaChat::Commands`.
- Refined the `directory_structure` tool description to warn about
  token usage and node growth relative to `max_depth`.

## 2026-07-06 v0.0.97

### Features
- Added `/context_format` command for managing context formats per session.
- Added database migration `005_add_context_format_to_sessions.rb` to include
  the `context_format` column in the `sessions` table.
- Added `context_format` state selector in
  `lib/ollama_chat/state_selectors.rb` using `DatabaseStateSelector`.
- Added `copy` subcommand to the `/persona` command.

### Improvements
- Updated `OllamaChat::Database::Models::Session` with presence validations
  and initialization for `context_format`.
- Updated `OllamaChat::InputContent#context_spook` and
  `OllamaChat::Tools::FileContext#execute` to use session-based format
  selection instead of static configuration.
- Refactored `OllamaChat::Chat#generate` to utilize `ollama.chat`, returning
  a string directly and supporting an optional `system` prompt.
- Implemented `OllamaChat::SystemPromptManagement#raw_system_prompt` for
  resolving active system prompts.
- Enhanced `OllamaChat::PromptManagement#suggest_prompts` with an `edit:`
  parameter and improved formatting.
- Updated the `embed` prompt template in `default_config.yml` to include
  `%{source}` for clarity.
- Modified `#embed` in `lib/ollama_chat/source_fetching.rb` to pass the
  `source` variable during interpolation.
- Added `disable_content_parsing` to `'update'` and `'embedding'` command
  paths in `lib/ollama_chat/commands.rb` to prevent recursive imports.
- Updated `select_persona_path` in `lib/ollama_chat/personae_management.rb`
  to support a `no_prefill` keyword argument.

### Fixes
- Added `validates_presence :profile` to the `validate` method in
  `lib/ollama_chat/database/models/model_options.rb`.
- Ensured character names are cast to strings in
  `lib/ollama_chat/parsing.rb` for type consistency.
- Corrected the help text flag in `lib/ollama_chat/information.rb` from `-s`
  to `-l`.
- Updated `/prompt` command regex and argument logic in
  `lib/ollama_chat/commands.rb`.

### Documentation
- Expanded `README.md` with detailed guides for `/input` and a new "Power
  User Features" section covering `/character`, `/prompt suggest`, `/model`
  profiles, and `/session summarize`.

## 2026-07-03 v0.0.96

### Features
- Added a `reroll` option to the `roll_dice` tool, allowing users to
  prompt for a new roll via `chat.confirm?`.
- Included `min` and `max` bounds in the JSON response and result message
  of the `roll_dice` tool.
- Added `offer_new_session: true` to session selection prompts in
  `SessionManagement` to allow starting a new session.
- Implemented `import_persona_from_json` in `PersonaeManagement` to import
  characters directly from JSON without temporary files.

### Improvements
- Enhanced human-readable `message` fields for `GetTime`,
  `GetCurrentWeather`, `ReadFile`, `WriteFile`, `GeneratePassword`,
  `RetrieveDocumentSnippets`, `ExecuteGrep`, `RunTests`, and `ComputeBMI`
  tools.
- Updated `convert_json_character_to_markdown` and
  `personalize_character_profile` to replace `{{char}}` and `{{user}}`
  placeholders with actual names using case-insensitive regexes.
- Refactored `PNGMetadataExtractor.decode_character` to return both the
  decoded string and parsed JSON data.
- Relocated `TokenEstimator` to a primary domain module and introduced an
  `Estimate` struct with `bytes_formatted` and `tokens_formatted` methods.
- Replaced the `it` parameter with `_1` in `ToolCalling` to improve
  compatibility with older Ruby versions.

### Build & CI
- Updated Ruby syntax across the project to use shorthand hash syntax in
  models, tools, and tests.
- Bumped `context_spook` dependency from **1.5** to **1.6**.

## 2026-06-29 v0.0.95

### Features
- Added `OllamaChat::Utils::PNGMetadataExtractor` to support
  extracting characters, prompts, and workflows from PNG `tEXt` chunks.
- Implemented `parse_a1111_parameters` to parse Automatic1111 Stable
  Diffusion WebUI parameters.
- Introduced `OllamaChat::Utils::UTF8Converter` for safe UTF-8 encoding.
- Consolidated metadata extraction logic into `OllamaChat::Parsing#parse_png`.
- Added a human-readable `message` field to `roll_dice` output.
- Added `delete_file`, `move_file`, `eval_ruby`, `get_ghr`, and
  `get_jira_issue` to the README tools table.

### Improvements
- Overhauled command help texts to use squiggly heredocs for better
  formatting and clarity.
- Added YARD documentation to the `OllamaChat::Commands` module.
- Increased `result_display_timeout` for `roll_dice` in
  `default_config.yml`.
- Expanded the README tools table to include `delete_file`, `move_file`,
  `eval_ruby`, `get_ghr`, and `get_jira_issue`.
- Refined README descriptions for the **Knowledge** category to
  distinguish between `retrieve_document_snippets` and `file_context`.
- Replaced `getconf _NPROCESSORS_ONLN` with `nproc` in CI scripts for
  better parallel job compatibility.

### Fixes
- Updated `OllamaChat::InputContent#all_file_set` to filter out
  directories and return a `Set`.
- Improved session name validation in
  `lib/ollama_chat/session_management.rb` by using `.blank?` instead of
  `.nil?`.
- Added `io.rewind` within an `ensure` block in PNG extraction logic to
  prevent read errors.

### Build & CI
- Removed the unused `json` dependency from `compute_bmi`.
- Removed the `PATCH_TOOL` definition and its corresponding documentation.
- Renamed `lib/ollama_chat/utils/png_character_extractor.rb` to
  `lib/ollama_chat/utils/png_metadata_extractor.rb`.
- Pruned redundant convenience methods `extract_prompt` and
  `extract_workflow` from `OllamaChat::Utils::PNGMetadataExtractor`.

## 2026-06-22 v0.0.94

### Features
- Added comprehensive test coverage for tool calling in
  `spec/ollama_chat/tool_calling_spec.rb`.
- Created a `LICENSE` file and updated `README.md` to link to the
  MIT license.

### Improvements
- Improved tool calling logic by utilizing the `tools_support` reader
  and ensuring allowed paths are indexed by string keys via `.to_s`.
- Synchronized search feedback prompts across `lib/ollama_chat/web_
  searching.rb`, `lib/ollama_chat/rag_handling.rb`, and
  `lib/ollama_chat/state_selectors.rb` using the `%s` format specifier.
- Updated usage examples in `lib/ollama_chat/utils/chooser.rb` to
  include the `%s` specifier.

### Testing
- Updated prompt expectations in
  `spec/ollama_chat/state_selectors_spec.rb`.

### Build & CI
- Added `LICENSE` and `spec/ollama_chat/tool_calling_spec.rb` to the
  gem specification files.

## 2026-06-21 v0.0.93

### Features
- Integrated search feedback into interactive chooser prompts across
  multiple modules, including favourites, prompts, sessions, and tool
  selection.

### Improvements
- Updated the `ollama-ruby` dependency to **1.22.0**.

### Testing
- Synchronized expectations in `spec/ollama_chat/input_content_spec.rb`
  to match updated prompt formats.

### Documentation
- Updated `CHANGES.md` with the release notes for **0.0.93**.

## 2026-06-19 v0.0.92

### Features
- Added a `/prompt suggest` subcommand to the CLI, enabling
  context-aware follow-up prompt generation based on the current
  conversation history.
- Introduced LLM-based reranking in the document retrieval tool via a
  new `rerank_records` method, utilizing a dedicated `rerank` prompt
  template to filter search results by relevance.
- Refactored the `execute` method in `retrieve_document_snippets` to
  use `flat_map`, improving the handling of records without tags.
- Added `suggest_prompts` and `prepare_conversation_history` methods to
  `OllamaChat::PromptManagement` to aggregate history and generate
  suggestions.
- Added `coding_suggest` and `roleplaying_suggest` prompt templates to
  the default configuration.

### Improvements
- Enhanced CLI user experience by replacing generic selection prompts
  with flavorful, context-aware messages across model, RAG, persona,
  and system prompt management modules.
- Expanded `choose_prompt` and `choose_system_prompt` methods to
  support custom prompt messages via a new `prompt` parameter.
- Added info-level logging for prompt and model details in `Chat#generate`
  to improve observability.
- Adjusted method visibility in `lib/ollama_chat/chat.rb` and
  `lib/ollama_chat/prompt_handling.rb` to allow tools to access core
  methods.

### Testing
- Updated `spec/ollama_chat/tools/retrieve_document_snippets_spec.rb` to
  cover the new `rerank` parameter and default behavior.
- Updated `spec/ollama_chat/input_content_spec.rb` and
  `spec/ollama_chat/state_selectors_spec.rb` to align with the updated
  `choose_entry` signatures.

## 2026-06-17 v0.0.91

### Fixes
- Coerce the return value of `choose_prompt.full?` to a string in `lib/ollama_chat/commands.rb` to prevent type-related issues.

## 2026-06-17 v0.0.90

### Features

- Add an edit option to the `/prompt` command via the `-e`
  flag, allowing users to modify a selected prompt using
  `edit_text`.

### Improvements

- Update the minimum `documentrix` dependency to **0.6.0** to
  leverage SQLite concurrency improvements and strong consistency
  for collection discovery.
- Modify `OllamaChat::RAGHandling#update_collection` to
  accumulate results from `embed` and return them as a
  newline-separated `String`.
- Update `lib/ollama_chat/commands.rb` to capture and return the
  output of the collection update command.

## 2026-06-15 v0.0.89

### Features
- Added support for model option profiles, including a new `profile`
  column in the database and a composite unique index on
  `[:model_name, :profile]`.
- Added the `-p` flag to `/model` and `/session` commands to specify a
  model profile for options management.
- Implemented `choose_profile_for_model` for interactive profile
  selection when a profile is not explicitly provided.
- Introduced `-t` and `-s` flags for the `/list` and `/last` commands to
  override thinking visibility, propagating the `think_loud` parameter
  through `OllamaChat::MessageList` and `OllamaChat::MessageFormat`.
- Added a `-e` flag to the `/input` command to allow editing imported
  content before it is added to the context.
- Added a `-e` flag to the `/output` command to allow editing the
  response before saving it to a file.
- Added a `-e` flag to the `/pipe` command to allow editing the response
  before piping it to another command.
- Updated the application to call `info_session` during the
  initialization of `OllamaChat::Chat` to display session information on
  startup.

### Improvements
- Standardized the use of the `-e` flag for editing across `/input`,
  `/regenerate`, `/pipe`, `/output`, `/copy`, and `/paste` commands.
- Replaced "Flags:" with "Options:" in help text for several chat
  commands.
- Extracted all chat command definitions into a new separate module
  `OllamaChat::Commands` located in `lib/ollama_chat/commands.rb`.
- Updated `OllamaChat::Chat` and the main library entry point to utilize
  the `OllamaChat::Commands` module instead of inline definitions.
- Enhanced `OllamaChat::MessageOutput#pipe` and `#output` to accept an
  `edit` parameter.
- Refactored `OllamaChat::MessageOutput#attempt_to_write_file` to receive
  raw content instead of a message object.
- Updated `OllamaChat::Information` to display all stored profiles and
  their options for the active model.

### Fixes
- Prevented persona path copies from triggering edit mode by passing
  `edit: false` to `perform_copy_to_clipboard` in `select_persona_path`.
- Corrected YARD documentation for the `edit` parameter in
  `lib/ollama_chat/clipboard.rb` and `lib/ollama_chat/message_output.rb`,
  changing the type from `Boolean` to `truthy/falsy`.

### Build & CI
- Added `lib/ollama_chat/commands.rb` to the `files` and
  `extra_rdoc_files` sections of the gemspec.

## 2026-06-03 v0.0.88

### Features
- Implemented a transition callback system for switches via the
  `PerformCallbacks` module, allowing `OllamaChat::Switches::Switch` and
  `OllamaChat::Switches::DatabaseSwitch` to trigger procs on state changes.
- Added conditional inclusion of `runtime_info` in the system prompt based
  on the state of `@chat.runtime_info.on?`.
- Added callbacks to the `@runtime_info` switch to trigger
  `reset_system_prompt` on state changes.

### Fixes
- Corrected control flow within the summary writing loop to prevent
  duplicate processing.

### Improvements
- Updated `change_system_prompt` in `lib/ollama_chat/chat.rb` to utilize
  `@messages.system_name` instead of `@system`.
- Refactored file handling in `lib/ollama_chat/input_content.rb` by adding
  a `skip_blank` parameter to `provide_file_set_content`, and updated
  `summarize`, `embed`, and `import` commands to use `skip_blank: true`.
- Simplified directory exclusion logic in `analyze_directory.rb` by using
  strings and `child.basename.fnmatch?` for pattern matching instead of
  expanded `Pathname` objects.
- Refactored `embed` and `embed_source` in
  `lib/ollama_chat/source_fetching.rb` using guard clauses.
- Updated the `embed` prompt in `default_config.yml` to change the
  formatting of the collection name.

### Documentation
- Clarified documentation for the `suffix` parameter in the
  `directory_structure` tool, including notes on filtering by file
  extensions.

### Testing
- Added test cases for the switch callback system in
  `spec/ollama_chat/switches_spec.rb`.
- Updated mocks in `spec/ollama_chat/chat_spec.rb`,
  `spec/ollama_chat/message_list_spec.rb`,
  `spec/ollama_chat/source_fetching_spec.rb`, and
  `spec/ollama_chat/utils/analyze_directory_spec.rb` to accommodate new
  code changes.

## 2026-05-28 v0.0.87

### Breaking
- Renamed the `/revise` command to `/regenerate` and updated associated
  help text and logic.
- Replaced the `switch` subcommand with `change` in the `/session`
  command to update session selection behavior.
- Merged the `/save` and `/load` commands into a unified
  `/conversation` command with `save` and `load` subcommands.
- Renamed the database column `default_persona_id` to
  `default_persona_name` and updated related method signatures.
- Removed the `-s` and `-p` startup options and the `OllamaChat::Utils::
  FileArgument` utility.
- Changed the default history file extension from `.json` to `.jsonl`.

### Features
- Added a `/character` command to import, load, and display persona
  information from `.png` and `.json` files.
- Implemented an `eval_ruby` tool for executing Ruby code in a
  sandboxed Docker environment.
- Introduced a `delete_file` tool that creates a backup before removing
  files and a `move_file` tool that prevents overwriting existing
  destinations.
- Added a `roll_dice` tool for parsing standard dice notation and
  generating random roll results.
- Implemented a `get_ghr` tool to fetch GitHub release data with support
  for pagination and specific repository lookups.
- Added support for tilde expansion in `all_file_set` patterns.
- Implemented persistent link sets for chat sessions with automatic
  synchronization and JSONL serialization.
- Added tagging support for document embedding and retrieval via the
  `/input` command and `retrieve_document_snippets` tool.
- Enabled the `/model sync` command to promote session-specific model
  options to global defaults.
- Added a `/session duplicate` command to copy existing sessions.
- Implemented bidirectional clipboard editing for copy and paste
  operations.
- Added a `/clear images` subcommand to purge images from the current
  chat session.
- Introduced a `generate_image` tool for creating images via ComfyUI
  with configurable filename prefixes.
- Added `reset` subcommands to `/prompt` and `/system` to revert prompt
  content to default values.
- Implemented `info` subcommands for `/prompt` and `/system` to display
  detailed template information.
- Added `duplicate` and `export` subcommands for prompts and system
  prompts.
- Implemented versioned database migrations using `Sequel::Migrator`.
- Added `think_strip` switch to toggle stripping of thinking content
  from output.
- Implemented `prepare_model` to synchronize thinking and tools support
  before generation.

### Fixes
- Fixed a shell injection vulnerability in the `run_tests` tool by using
  `Open3.popen2e` and `Shellwords.escape`.
- Prevented shell injection in `config_handling` and `patch_file` tools
  by using the array form of `system`.
- Secured path validation against symlink traversal by resolving physical
  paths with `realpath`.
- Fixed `PatchFile` filename generation to ensure correct file
  identification during patching.
- Resolved an encoding error in PNG character extraction by enforcing
  valid `UTF-8` encoding.
- Fixed a crash in the `/favourite` command when the resource type was
  `nil` by making the type mandatory.
- Corrected the `WriteFile` tool to return the proper string path in its
  result hash.
- Ensured the assistant's final response is persisted to the session
  store after each interaction.
- Fixed `Tempfile` usage in Vim to prevent race conditions by using
  `Tempfile.open` without a block.

### Improvements
- Refactored error handling to use custom `ExecuteError` and `HTTPError`
  exceptions instead of the `reraise` flag.
- Centralized link tracking in `get_url` to remove redundant additions
  from other modules.
- Refactored `OllamaChat::Utils::Fetcher::HeaderExtension` to
  `ResponseMetadata` and added `response_status` and `response_reason`
  accessors.
- Refactored `OllamaChat::Utils::Chooser` to a stateful mixin using
  `Tins::DynamicScope` for better search context management.
- Refactored message handling into a dedicated `OllamaChat::Message`
  class with `MessageMixin` for content stripping.
- Centralized text editing logic in `OllamaChat::FileEditing` with
  `edit_text_block` for consistent editor integration.
- Optimized `GetGHR` tool with pagination support and refactored HTTP
  request logic.
- Refactored session name derivation to use raw messages and improved
  validation to prevent duplicate names.
- Improved session list display with lock indicators, token estimates,
  and truncated names.
- Enhanced `GetURL` tool to support various document policies and media
  types.
- Refactored system prompts to use a reference-based database registry
  with template interpolation.
- Standardized the export flow for personae, prompts, and system prompts
  to a "Select → Preview → Destination" sequence.
- Added visual indicators to state selectors using emoji and
  `SearchUI::Wrapper`.
- Integrated token estimation into session and persona lists using
  `OllamaChat::Utils::TokenEstimator`.
- Refactored `OllamaChat::MessageList` to use `OllamaChat::Utils::
  JSONJSONLIO` for unified JSON and JSONL handling.
- Updated `Reline` integration for history management and `ask?` prefill
  mechanisms.
- Refactored `OllamaChat::History` to support multiple namespaces for
  `Reline` history swapping.
- Moved chat history storage from files to a `sessions` table column.
- Refactored database models to move `Duplicatable` and `SessionLocking`
  into the `OllamaChat::Database` namespace.
- Implemented Vim-style exclusive session locking with PID tracking.
- Added directory-aware session retrieval to prioritize sessions from
  the current working directory.
- Refactored `/info` command to support focused subcommands for session,
  model, runtime, and RAG details.
- Improved `confirm?` and `ask?` readability with multi-line structures
  and `then` clauses.
- Updated `OllamaChat::Tools::GetGHR` description to clearly define
  operational modes.
- Refactored `OllamaChat::PersonaeManagement` to use a `persona_
  description` helper for centralized formatting.
- Normalized collection logging in source fetching for consistent output.
- Stripped whitespace from input commands to prevent processing errors.
- Filtered non-existent paths from tool allowed lists to avoid model
  confusion.
- Refactored `handle_tool_call_results?` to use `concat` and ensure
  proper cleanup.
- Improved patch application feedback to detect rejected patches via
  content checksums.
- Refactored persona command to include a `play` subcommand and path
  selection.
- Implemented versioned database migrations to support schema changes.
- Refactored `WriteFile` tool to return correct path strings and use
  consistent variable naming.
- Added `result_display_timeout` to `retrieve_document_snippets` and
  `patch_file` configurations.
- Standardized cancellation messages to "Cancelled." across modules.
- Included thinking content in session summaries with explicit
  separation.
- Enhanced session summarization by providing accumulated context.
- Refactored sender name display logic to use a `sender_name_displayed`
  helper.
- Added an infobar to message list output for progress tracking.
- Refactored PNG character profile extraction to use a dedicated
  `parse_character_json` method.
- Simplified collection access with a `collection` helper method.
- Removed the unused `parse_csv` method from the `Parsing` module.
- Implemented image clearing for chat sessions with a `/clear images`
  subcommand.
- Truncated session names in the session management table to 40
  characters.
- Implemented custom sender names for chat messages with terminal
  styling.
- Added an option to save cleaned conversations via the `/conversation
  save` command.
- Alphabetized runtime information hash keys and added weekday support.
- Fixed encoding in PNG character extraction for valid UTF-8 output.
- Integrated PNG character profile extraction into parsing.
- Added PNG character extraction utility and fixed ANSI encoding issues.
- Estimated tool output tokens using `OllamaChat::Utils::
  TokenEstimator`.
- Differentiated session lock owners with distinct emoji indicators.
- Added lock status and improved display formatting to the session list.
- Added `tools_support` to the system prompt template.
- Used modern block parameters for URI decoding in `OC`.
- Refactored variable substitution in persona profiles to a dedicated
  method.
- Updated prompt input hints to include `C-u` for clearing input.
- Improved session renaming logic with validation to prevent unique
  constraint violations.
- Fixed YARD documentation across various modules for accuracy.
- Refined YARD documentation for `switches.rb` to improve precision.
- Improved readability of `confirm?` and `ask?` calls across files.
- Used heredoc for persona roleplay prompts to improve formatting.
- Escaped percent signs in persona profiles to prevent interpolation
  errors.
- Split runtime info into static and dynamic contexts for better
  system prompt management.
- Removed image path listing from message text output.
- Initialized session attributes with unconditional defaults.
- Exposed embedding collection descriptions to the LLM via runtime
  information.
- Enabled user interpolation in persona profiles.
- Refactored user retrieval in the information module to use a
  dedicated `user` method.
- Simplified `play_persona` API to accept a single argument.
- Refined persona selection and result loading logic for better
  encapsulation.
- Refactored persona management naming to remove redundant `_prompt`
  suffixes.
- Renamed `default_persona_id` to `default_persona_name` in the
  database.
- Allowed specifying document collections for retrieval in the
  `retrieve_document_snippets` tool.
- Added a `persona` system prompt to the default configuration.
- Improved chat help, README, and added a Sherlock persona example.
- Added pattern-based filtering to the `/help` command.
- Updated README to reflect session-based CLI options.
- Added session duplication and unique validations for sessions.
- Refined session initialization and system prompt default fallback.
- Improved and corrected YARD documentation for various modules.
- Modularized info commands and refined the dashboard view.
- Refactored database models and enhanced session management.
- Refactored system prompts, personae, and export flows.
- Included prompt in image generation tool responses.
- Refactored message handling into `OllamaChat::Message`.
- Refactored `run_tests` tool and improved path validation.
- Enhanced state selector with visual indicators for selection.
- Improved token visibility and polished CLI prompts.
- Refined byte formatting and added token formatting utility.
- Implemented prompt duplication and export features.
- Enhanced `GetURL` tool and refined source fetching logic.
- Added token estimator utility to gemspec.
- Added model families to metadata and info output.
- Extracted token estimation to a shared utility.
- Added `generate_image` tool and updated rubygems version.
- Renamed session switch command to change.
- Standardized tool argument and operational errors.
- Allowed customizable filename prefix for image generation.
- Implemented ComfyUI image generation tool and configuration.
- Documented `Prompt` model and added favourites cleanup hook.
- Implemented favourites support for personae.
- Ensured session persists after assistant response.
- Refactored `/input` command to use a `-p` flag for patterns.
- Improved session locking error messages with detailed information.
- Used `session_close` instead of `store_messages_in_session` in
  configuration handling.
- Improved personae selection and default handling.
- Refactored model preparation and capability synchronization.
- Handled `nil` content in `strip_internal_json_markers`.
- Secured session timestamps and added model validations.
- Refactored session age calculation and list display.
- Implemented new session creation flag and improved error messages.
- Improved session selection and exit handling.
- Added `session_locking.rb` to gemspec files.
- Implemented Vim-style exclusive session locking.
- Added directory-aware session retrieval.
- Notified users when renaming a session to its current name.
- Improved `rename_session` documentation and persona configuration.
- Updated prompts to use `C-u` for clearing input.
- Added YARD documentation to internal JSON stripping method.
- Optimized persona listing using a Schwartzian Transform.
- Supported multiple results for parallel tool calls.
- Improved `ask?` with `Reline` prefill and UX polish.
- Updated `initial_model` logic and documentation.
- Refactored text editing to a centralized block pattern.
- Improved portability of `patch_file` specs.
- Expanded favourites system to prompts and system prompts.
- Mocked diff tool in `patch_file` specs.
- Updated `unix_socks` dependency for secure sockets.
- Prevented shell injection in `run_tests`, `config_handling`, and
  `patch_file` tools.
- Secured path validation against symlink traversal.
- Enhanced prompt and system prompt management.
- Moved session prompts to default configuration.
- Enhanced system prompt and session management.
- Updated collection handling and added YARD documentation.
- Updated `compose` method to accept optional initial content.
- Added `UPDATED` column to session table.
- Implemented base prompt handling and management logic.
- Implemented prompt editor and unified management naming.
- Moved prompt management to the database.
- Improved YARD docs and polished `MessageList`.
- Bumped version to **0.0.87**.
- Used `Tempfile.open` instead of `Tempfile.create` in Vim.
- Improved session display in session handling.
- Refactored `patch_file` tool and standardized `Tempfile` usage.
- Allowed promoting session model options to global defaults.
- Refactored model options handling and session commands.
- Showed persona file path in `info_persona`.
- Updated `each_line` mock in `chat_spec.rb`.
- Used `\A` anchor for `confirm?` regex matches.
- Added support for JSONL chat history format.
- Refined session title generation logic.
- Normalized tool keys to strings in the session model.
- Added `compute_bmi` tool and spec.
- Improved tag wrapping in `collection_stats`.
- Refactored error logging in `fetcher.rb`.
- Added content parsing control methods for better chat session
  management.
- Improved debug output formatting for better log readability.
- Removed vim editor configuration line from `Rakefile`.
- Ensured consistent time and weekday in runtime information.
- Added weekday information to time tool output.
- Centralized link registration in `search_web`.
- Added BMI calculation tool and tests.
- Refactored conversation commands into a namespace.
- Updated embedding and splitting configuration.
- Implemented Sequel-based database support.
- Added JSON and JSONL persistence to `MessageList`.
- Implemented `think_strip` switch.
- Added interactive system prompt loading functionality.
- Refined file set reading and path handling.

### Build & CI
- Switched CI images from alpine to debian trixie for Ruby versions
  **4.0**, **3.4**, **3.3**, and **3.2**.
- Updated `documentrix` dependency to **0.4.0** in `Rakefile` and
  `ollama_chat.gemspec`.
- Updated `search_ui` dependency to version **0.2** or higher.
- Updated `documentrix` dependency to **0.3.2** in `Rakefile` and
  `ollama_chat.gemspec`.
- Updated `documentrix` dependency to **0.3.1** in `Rakefile` and
  `ollama_chat.gemspec`.
- Updated `documentrix` to **0.3.0** in `Rakefile` and
  `ollama_chat.gemspec`.
- Updated `documentrix` dependency to >= **0.2.0** in `Rakefile`.
- Updated `unix_socks` gem dependency to version **>= 0.4** in
  `Rakefile` and `ollama_chat.gemspec`.
- Updated `tins` gem to version **1.53** in `Rakefile` and
  `ollama_chat.gemspec`.
- Updated `sequel` (**5.0**) and `rubygems_version` (**4.0.10**)
  dependencies.
- Updated `gem_hadar` dependency to version **2.17.1** in
  `ollama_chat.gemspec`.
- Updated `ollama_chat.gemspec` file lists to include new files.
- Added `lib/ollama_chat/utils/token_estimator.rb` to `s.extra_
  rdoc_files` and `s.files`.
- Added `lib/ollama_chat/utils/json_jsonl_io.rb` to `s.extra_
  rdoc_files` and `s.files`.
- Added `lib/ollama_chat/session_locking.rb` to `s.extra_rdoc_files`
  and `s.files`.
- Added `lib/ollama_chat/database/duplicatable.rb` to `s.extra_
  rdoc_files`.
- Added `lib/ollama_chat/tools/generate_image.rb` to `s.extra_
  rdoc_files` and `s.files`.
- Added `spec/ollama_chat/history_spec.rb` to `s.test_files`.

### Testing
- Added expectation for the `confirm?` call in `source_fetching_spec`.
- Added comprehensive test suites for `delete_file` and `move_file`
  tools.
- Added `spec/assets/fluffy.png` and tests for PNG character extraction.
- Expanded test coverage for `run_tests` tool to include failures and
  path auto-discovery.
- Updated specs to verify the new exception-based error flow.
- Updated `get_ghr_spec.rb` to verify pagination and new URL patterns.
- Updated `patch_file_spec.rb` by removing unnecessary `.full?` calls.
- Added `spec/ollama_chat/tools/get_ghr_spec.rb`.
- Expanded test suites for clipboard editing functionality.
- Updated test suites for `Chooser` refactoring.
- Updated and added test cases for tagging flow.
- Added a mock for `confirm?` in `chat_spec.rb` within the `embedding`
  context.
- Updated and add test cases in `chat_spec.rb` and `retrieve_document_
  snippets_spec.rb`.
- Updated specs to reflect changes in `MessageList` and `History`.
- Updated `follow_chat_spec.rb` to reflect changes in assistant's
  display output.
- Updated `spec/ollama_chat/chat_spec.rb` to verify the `/clear images`
  functionality.
- Updated `spec/ollama_chat/chat_spec.rb` to test the new `/
  conversation` syntax.
- Updated `spec/ollama_chat/message_list_spec.rb` to include test cases
  for JSON and JSONL loading and saving.
- Updated `spec/ollama_chat/vim_spec.rb` to match `Tempfile.open` call.
- Updated `spec/ollama_chat/tools/patch_file_spec.rb` to mock
  `Tempfile.create`.
- Updated `spec/ollama_chat/tools/read_file_spec.rb` to cover
  `extract_range` branches.
- Updated `spec/ollama_chat/database/models/favourite_spec.rb` to
  expect `Sequel::ValidationFailed`.
- Updated `spec/ollama_chat/chat_spec.rb` to use `context 'JSON'` and
  `context 'JSONL'` for history tests.
- Updated `spec/ollama_chat/tools/get_ghr_spec.rb` to verify pagination
  logic.
- Updated `spec/ollama_chat/tools/patch_file_spec.rb` to dynamically
  resolve `OC::DIFF_TOOL`.
- Updated `spec/ollama_chat/tools/patch_file_spec.rb` to mock `OC::
  DIFF_TOOL` as `/bin/true`.
- Updated `spec/ollama_chat/file_editing_spec.rb` and related specs for
  text editing refactoring.
- Updated `spec/ollama_chat/message_list_spec.rb` to mock `static_
  runtime_information`.
- Updated `spec/ollama_chat/chat_spec.rb` to reflect new `save_
  conversation` signature.
- Updated `spec/ollama_chat/information_spec.rb` to reflect new method
  names.
- Updated `spec/ollama_chat/follow_chat_spec.rb` to reflect changes in
  assistant's display output.
- Updated `spec/ollama_chat/chat_spec.rb` to verify new flag-based
  syntax for pattern inputs.
- Updated `spec/ollama_chat/vim_spec.rb` to match `Tempfile.open` call.
- Updated `spec/ollama_chat/tools/patch_file_spec.rb` to mock
  `Tempfile.create`.
- Updated `spec/ollama_chat/utils/fetcher_spec.rb` to verify temporary
  file types.
- Updated `spec/ollama_chat/tools/read_file_spec.rb` to cover
  `extract_range` branches.
- Updated `spec/ollama_chat/database/models/favourite_spec.rb` to
  expect `Sequel::ValidationFailed`.
- Updated `spec/ollama_chat/chat_spec.rb` to use `context 'JSON'` and
  `context 'JSONL'` for history tests.
- Updated `spec/ollama_chat/tools/get_ghr_spec.rb` to verify pagination
  logic.
- Updated `spec/ollama_chat/tools/patch_file_spec.rb` to dynamically
  resolve `OC::DIFF_TOOL`.
- Updated `spec/ollama_chat/tools/patch_file_spec.rb` to mock `OC::
  DIFF_TOOL` as `/bin/true`.
- Updated `spec/ollama_chat/file_editing_spec.rb` and related specs for
  text editing refactoring.
- Updated `spec/ollama_chat/message_list_spec.rb` to mock `static_
  runtime_information`.
- Updated `spec/ollama_chat/chat_spec.rb` to reflect new `save_
  conversation` signature.
- Updated `spec/ollama_chat/information_spec.rb` to reflect new method
  names.
- Updated `spec/ollama_chat/follow_chat_spec.rb` to reflect changes in
  assistant's display output.
- Updated `spec/ollama_chat/chat_spec.rb` to verify new flag-based
  syntax for pattern inputs.

### Documentation
- Fixed a typo in the YARD documentation for `confirm?`.
- Improved `GetGHR` tool description to clearly define operational
  modes.
- Refined YARD documentation for `ResponseMetadata` attributes.
- Added YARD documentation for `extract_range` in `read_file` tool.
- Updated README to reflect session-based CLI options.
- Updated `help` strings in `chat.rb` for various commands.
- Added YARD documentation for `parse_character_json`.
- Updated YARD documentation for `images`, `sender_name`, and `as_json`.
- Added YARD documentation for `OllamaChat::Utils::TokenEstimator`.
- Added YARD documentation for `format_tokens`.
- Added YARD documentation for `choose` method in state selectors.
- Added YARD documentation for `static_runtime_information` and related
  methods.
- Added YARD documentation for `duplicate` method in `Duplicatable`
  module.
- Corrected inaccurate parameter descriptions in `rag_handling.rb`.
- Updated YARD comments for `change_system_prompt`.
- Relocated module-level documentation for `TokenEstimator`.
- Added YARD documentation for `format_tokens` in `value_formatter.rb`.
- Updated YARD documentation for `list_conversation`, `show_last`,
  `drop`, and `set_system_prompt`.
- Added YARD attribute documentation for `Prompt` model.
- Added missing YARD attribute comments for `Session` model.
- Added YARD documentation for `Persona` management methods.
- Added YARD documentation for `Prompt` and `SystemPrompt` management
  methods.
- Added YARD documentation for `PromptHandling` module.
- Added YARD documentation for `SetCurrentCollection` method.
- Added YARD documentation for `EditTextBlock` and related methods.
- Added YARD documentation for `Ask?` method improvements.
- Updated YARD documentation for `InitialModel` method.
- Added YARD documentation for `StripAllInternalJsonMarkers`.
- Refined YARD documentation for `DeletePersona` and `ListPersonae`.
- Added YARD documentation for `PrepareModel` method.
- Added YARD documentation for `AllModels` method.
- Added YARD documentation for `RenameSession` method.
- Added YARD documentation for `SessionLocking` module.
- Added YARD documentation for `SessionManagement` methods.
- Added YARD documentation for `FavouritesManagement` methods.
- Added YARD documentation for `PromptManagement` methods.
- Added YARD documentation for `SystemPromptManagement` methods.
- Added YARD documentation for `PersonaeManagement` methods.
- Added YARD documentation for `FileEditing` methods.
- Added YARD documentation for `MessageList` methods.
- Added YARD documentation for `Chat` module methods.
- Added YARD documentation for `Dialog` module methods.
- Added YARD documentation for `Information` module methods.
- Added YARD documentation for `ModelHandling` module methods.
- Added YARD documentation for `RAGHandling` module methods.
- Added YARD documentation for `ToolCalling` module methods.
- Added YARD documentation for `WebSearching` module methods.
- Added YARD documentation for `InputContent` module methods.
- Added YARD documentation for `MessageEditing` module methods.
- Added YARD documentation for `MessageOutput` module methods.
- Added YARD documentation for `ConfigHandling` module methods.
- Added YARD documentation for `Conversation` module methods.
- Added YARD documentation for `FollowChat` module methods.
- Added YARD documentation for `StateSelectors` module methods.
- Added YARD documentation for `Switches` module methods.
- Added YARD documentation for `Vim` module methods.
- Added YARD documentation for `Utils` module methods.
- Added YARD documentation for `Database` module methods.
- Added YARD documentation for `Models` module methods.
- Added YARD documentation for `Migrations` module methods.
- Added YARD documentation for `Duplicatable` module methods.
- Added YARD documentation for `SessionLocking` module methods.
- Added YARD documentation for `Fetcher` module methods.
- Added YARD documentation for `CacheFetcher` module methods.
- Added YARD documentation for `PathValidator` module methods.
- Added YARD documentation for `TokenEstimator` module methods.
- Added YARD documentation for `ValueFormatter` module methods.
- Added YARD documentation for `PNGCharacterExtractor` module methods.
- Added YARD documentation for `JSONJSONLIO` module methods.
- Added YARD documentation for `Backup` module methods.
- Added YARD documentation for `Chooser` module methods.
- Added YARD documentation for `SearchUI` integration methods.
- Added YARD documentation for `Reline` integration methods.
- Added YARD documentation for `Tins` integration methods.
- Added YARD documentation for `KramdownANSI` integration methods.
- Added YARD documentation for `Sequel` integration methods.
- Added YARD documentation for `Docker` integration methods.
- Added YARD documentation for `UnixSocks` integration methods.
- Added YARD documentation for `Open3` integration methods.
- Added YARD documentation for `Shellwords` integration methods.
- Added YARD documentation for `Tempfile` integration methods.
- Added YARD documentation for `File` integration methods.
- Added YARD documentation for `Pathname` integration methods.
- Added YARD documentation for `URI` integration methods.
- Added YARD documentation for `JSON` integration methods.
- Added YARD documentation for `YAML` integration methods.
- Added YARD documentation for `Time` integration methods.
- Added YARD documentation for `Date` integration methods.
- Added YARD documentation for `Regexp` integration methods.
- Added YARD documentation for `String` integration methods.
- Added YARD documentation for `Array` integration methods.
- Added YARD documentation for `Hash` integration methods.
- Added YARD documentation for `Set` integration methods.
- Added YARD documentation for `IO` integration methods.
- Added YARD documentation for `FileDescriptor` integration methods.
- Added YARD documentation for `Process` integration methods.
- Added YARD documentation for `Thread` integration methods.
- Added YARD documentation for `Monitor` integration methods.
- Added YARD documentation for `Mutex` integration methods.
- Added YARD documentation for `Queue` integration methods.
- Added YARD documentation for `ConditionVariable` integration methods.
- Added YARD documentation for `Struct` integration methods.
- Added YARD documentation for `Data` integration methods.
- Added YARD documentation for `Enumerator` integration methods.
- Added YARD documentation for `Fiber` integration methods.
- Added YARD documentation for `GC` integration methods.
- Added YARD documentation for `Signal` integration methods.
- Added YARD documentation for `Errno` integration methods.
- Added YARD documentation for `Exception` integration methods.
- Added YARD documentation for `StandardError` integration methods.
- Added YARD documentation for `RuntimeError` integration methods.
- Added YARD documentation for `TypeError` integration methods.
- Added YARD documentation for `ArgumentError` integration methods.
- Added YARD documentation for `NameError` integration methods.
- Added YARD documentation for `NoMethodError` integration methods.
- Added YARD documentation for `StopIteration` integration methods.
- Added YARD documentation for `SystemExit` integration methods.
- Added YARD documentation for `Interrupt` integration methods.
- Added YARD documentation for `SignalException` integration methods.
- Added YARD documentation for `NotImplementedError` integration methods.
- Added YARD documentation for `RangeError` integration methods.
- Added YARD documentation for `FloatDomainError` integration methods.
- Added YARD documentation for `RangeError` integration methods.
- Added YARD documentation for `RegexpError` integration methods.
- Added YARD documentation for `ScriptError` integration methods.
- Added YARD documentation for `SyntaxError` integration methods.
- Added YARD documentation for `LoadError` integration methods.
- Added YARD documentation for `NotImplementedError` integration methods.

## 2026-04-02 v0.0.86

### Features
- Added a `backup` subcommand for the `/persona` command to
  preserve persona file contents.
- Wrapped `enable_tool` and `disable_tool` in a loop to allow
  multiple selections before exiting.

### Fixes
- Corrected the rescue exception in `use_model` to
  `OllamaChat::UnknownModelError`.
- Ensured float division for duration calculations in
  `eval_stats` of `FollowChat`.
- Enabled tilde path expansion in directory checks in `parsing.rb`
  using `Pathname#expand_path`.

### Improvements
- Removed tag support from `parse_content`, simplifying the return
  value to a single `String`.
- Updated `play_persona_prompt` to include "(no need to read the
  file)" in the roleplay prompt template.
- Made the `edit` subcommand of `/revise` and the `/links` command
  optional.
- Removed the deprecated `-d` flag from the `/input` command.
- Updated the `file_context` tool description for accuracy.

### Build & CI
- Bumped the `documentrix` dependency to `>= 0.1.1`.

### Documentation
- Added YARD documentation to the `Command` class in
  `command_concern.rb`.
- Reformatted command registration code in `command_concern.rb` for
  readability.

## 2026-03-29 v0.0.85

### Features
- Added `list` and `rename` subcommands to the `/collection` command
  in `lib/ollama_chat/chat.rb` to display available collections and
  rename them via the `rename_collection` method in
  `lib/ollama_chat/dialog.rb`.
- Made the `/collection` command optional so that running it without
  arguments displays collection statistics by invoking the
  `collection_stats` method.
- Introduced progress feedback in
  `lib/ollama_chat/input_content.rb` within the
  `provide_file_set_content` method to display batch processing status.

### Fixes
- Corrected the warning condition in `OllamaChat::FollowChat` by
  fixing the success check in `lib/ollama_chat/follow_chat.rb`.
- Prevented loading a default persona if the conversation already
  contains messages in `lib/ollama_chat/personae_management.rb`.

### Build & CI
- Updated the `documentrix` dependency from **0.0.4** to **0.1.0** in
  `Rakefile` and `ollama_chat.gemspec`.

### Testing
- Updated tests in `spec/ollama_chat/chat_spec.rb` to accommodate new
  command options and collection handling.

### Documentation
- Updated `README.md` to reflect new `/collection` command options and
  adjusted help text.

## 2026-03-26 v0.0.84

### Features
- Added `OllamaChat::Utils::ValueFormatter` with the `format_bytes` helper.
- Implemented the `RetrieveDocumentSnippets` tool to search local documents.
- Updated tool payloads to include a `message` key for improved feedback.
- `browse` now returns specific success or failure messages.
- `write_file`, `patch_file`, and `paste_from_clipboard` now report byte sizes.

### Improvements
- Refactored `Dialog#confirm?` to accept a `yes:` keyword for regex matching.
- Updated `Dialog#confirm?` to display colored emojis based on user response.
- Standardized tool output formatting to include human-readable sizes.
- Moved document retrieval logic from `Chat` to the new tool.
- Updated `OllamaChat::Utils` to require `value_formatter`.

### Testing
- Added specs for the `RetrieveDocumentSnippets` tool.
- Updated specs for `browse`, `search_web`, and `paste_from_clipboard`.
- Updated specs for `open_file_in_editor` and `resolve_tag`.

## 2026-03-24 v0.0.83

### Features

- Added `timeout:` and `default:` parameters to `Dialog#confirm?` to
  support timed prompts, returning the default value upon timeout.
- Implemented display timeouts for tool results in `FollowChat`, using
  `result_display_timeout` settings to control prompt duration.
- Added `result_display_timeout` configuration options to tool
  definitions in `default_config.yml`, setting standard timeouts.

### Fixes

- Normalized namespaced tool calls in `FollowChat` by extracting the
  basename from names containing slashes, ensuring correct tool lookup.
- Converted `@documents.collections` to an array in
  `Dialog#choose_collection` to prevent concatenation errors when the
  collection is not an array.

## 2026-03-21 v0.0.82

### Features
- Added a `kinds` method to `OllamaChat::Utils::TagResolver` that returns
  a hash mapping ctags kind identifiers to human-readable descriptions.
- Updated the `kind` parameter description in `OllamaChat::Tools::ResolveTag`
  to include JSON output from `OllamaChat::Utils::TagResolver.kinds`.

### Fixes
- Corrected the tag-parsing regex in `OllamaChat::Utils::TagResolver` to
  capture the `rest` field (`.*`) so all columns are correctly parsed.
- Refactored `kind_of` to use the new `kinds` mapping instead of a
  non-existent `@kinds` hash.

### Improvements
- Added bell (🔔) and question mark (❓) emojis to various `confirm?` and
  `ask?` prompts across multiple modules for clearer user experience.
- Updated the prompt string in `OllamaChat::FollowChat` to `⏎  Press any
  key to continue. ` for better display alignment.
- Refined the description of `OllamaChat::Tools::PasteIntoEditor` to use
  `text` instead of `string` and clarified that no file or line is required
  when pasting into the editor.

### Build & CI
- Updated the `kramdown-ansi` dependency requirement from **0.3** to
  **0.5** in the `Rakefile` and `ollama_chat.gemspec`.
- Bumped the `ollama-ruby` dependency version from **1.18** to **1.21**
  in the `Rakefile` and `ollama_chat.gemspec`.

### Testing
- Added a `before` block to the `resolve_tag` spec that sets
  `OC::OLLAMA::CHAT::TOOLS::CTAGS_TOOL` to `true` for consistent test
  configuration.

## 2026-03-20 v0.0.81

### Features
- Added `./` file path completion to the Reline CLI.
- Added `OC::USER` configuration variable to expose the user's name in
  runtime information and default prompts.
- Added a duration metric to tool call results, formatting elapsed time with
  `Tins::Duration`.

### Improvements
- Extracted `http_options` and `get_url` logic into a new `HTTPHandling`
  module, refactoring tools to use the chat instance for HTTP requests.
- Extracted path completion logic into a new `PathCompleter` utility class to
  improve testability and code organization.
- Added `debug` flag from configuration to the fetcher call in `get_url`.

### Build & CI
- Added `http_handling.rb` and `path_completer.rb` to gemspec file lists to
  ensure proper packaging and documentation.

### Testing
- Added tests for the `PathCompleter` utility class.
- Updated tool tests to pass the `chat` instance instead of `config`.
- Updated chat tests to set `OC::PAGER` to `nil` for cleaner output.

## 2026-03-18 v0.0.80

### Breaking
- Replaced individual toggle commands with a unified `/toggle` command.
- Consolidated `/import`, `/summarize`, `/embed`, `/input`, and `/context`
  commands into a unified `/input` command.
- Renamed the `/voice change` subcommand to `/voice`.

### Features
- Added a `command` DSL in `OllamaChat::CommandConcern` for registering chat
  commands.
- Added a `suffix` parameter to the `directory_structure` tool for filtering
  files by extension.
- Added a `confirm?` method for single-character confirmation prompts.
- Added an interactive persona reload menu to `reload_default_persona`.
- Added a `check_file` flag to `assert_valid_path` for verifying file
  existence.
- Added a `-c` flag to skip persona setup when loading existing
  conversations.
- Added helper methods `file_set_each`, `all_file_set`, and
  `provide_file_set_content` for file set processing.

### Fixes
- Fixed link list numbering width in chat output.
- Fixed runtime information display to use JSON format.
- Fixed `tools_used` check in `handle_tool_calls` to correctly identify when
  all tool results are processed.

### Improvements
- Refactored output handling to use `use_pager` for consistent paging.
- Updated retrieval snippet injection to use JSON blocks.
- Updated `source_fetching` to coerce sources to string and lazy load links.
- Updated path validation to raise `OllamaChat::InvalidPathError` for
  non-existent files.
- Standardized `@return` documentation comments for tool registration.
- Updated `/revise` command to strip internal JSON markers from message
  content.
- Truncated user query to embedding model context length before retrieval.
- Updated `context_spook` to use `file_set_each` for file processing.

### Build & CI
- Added `reline` gem to dependencies.

### Testing
- Updated specs to stub `OC::PAGER` and verify pager usage.
- Updated test expectations for new command handling and help output.
- Updated path validation tests to expect `OllamaChat::InvalidPathError`.
- Added test cases for `directory_structure` suffix filtering.
- Added `asset_pathname` helper in `spec_helper.rb`.

### Documentation
- Updated `README.md` to show the new `/toggle` syntax and expanded command
  table.
- Updated `bin/ollama_chat_send` help text to reflect the renamed `/input`
  command.
- Removed redundant `@see` documentation comments.

## 2026-03-13 v0.0.79

### Features
- Added `tmp/*` to `.gitignore` and the Rakefile ignore list.
- Created a new `OllamaChat::Logging` module that lazily builds a `Logger`
  writing to the file defined by `OC::OLLAMA::CHAT::LOGFILE`.
- Implemented `OllamaChat::Logging#log(severity, msg, warn:)` which formats
  exceptions with backtraces and forwards messages to the Ruby `Logger`.
- Included the `OllamaChat::Logging` module in `class OllamaChat::Chat` to
  provide logging capabilities to every chat instance.
- Added optional `before`, `after`, and `context` parameters to the
  `execute_grep` tool for context-aware search results.
- Added a private `digest` method to the `patch_file` tool that returns the
  MD5 of a file path.
- Added a new config entry for `LOGFILE` under the state home directory in
  `oc.rb`.

### Improvements
- Switched chat history storage from XDG CACHE to XDG STATE by updating the
  `OC::OLLAMA::CHAT::HISTORY` path.
- Refactored logging across multiple files to replace `logger.error` and
  `logger.warn` calls with the new `log` helper method.
- Updated the `execute_grep` tool to use a `normalize_number` helper for
  handling optional integer arguments.
- Enhanced the `patch_file` tool to verify patch application success by
  comparing file digests before and after the patch.
- Improved error handling in the `patch_file` tool to include a `success`
  flag and clearer error messages.
- Updated the `default_config.yml` command template for `execute_grep` to
  include `-B`, `-A`, and `-C` flags based on provided values.

### Fixes
- Added an explicit check in the `patch_file` tool to ensure the path is not
  empty, raising an `ArgumentError` if missing.
- Fixed a URL typo in `README.md` for the project homepage.

### Build & CI
- Updated the gemspec to include `logging.rb` in `extra_rdoc_files` and
  `files`.
- Added `tmp/*` to the Rakefile ignore list for cleaner builds.

### Documentation
- Removed the `Runtime Directory` (`-d`) section from `README.md`.
- Updated `patch_file` tool documentation to specify `unified diff format`
  and JSON response behavior.

### Testing
- Updated `spec_helper.rb` to set temporary paths for `OC::OLLAMA::CHAT::HISTORY`
  and `LOGFILE` in a global `config.before` hook.

## 2026-03-11 v0.0.78

### Features
- Added `patch_file` tool for applying unified diff patches to files with
  safety checks and path validation.
- Added `default_persona_name` helper to display the active persona name.

### Improvements
- Introduced `runtime_information` and `runtime_information_values` helpers
  to centralize and simplify runtime data formatting.
- Added a path validation whitelist to the `run_tests` tool to restrict
  execution to allowed directories.
- Updated `search_ui` dependency to **0.1** and refactored `model_handling`
  to use `SearchUI::Wrapper` for improved display and dispatch.
- Clarified `DirectoryStructure` tool description to specify `max_depth`
  limits.
- Enabled location tracking by default in `default_config.yml`.

### Build & CI
- Renamed environment variable `OLLAMA_CHAT_TOOLS_RUN_TESTS_TEST_RUNNER` to
  `OLLAMA_CHAT_TOOLS_TEST_RUNNER`.
- Enabled location tracking by default in `default_config.yml`.

### Testing
- Removed redundant `require 'spec_helper'` statements from all spec files
  and added global loading via `.rspec`.
- Added specs for the new `patch_file` tool functionality.

## 2026-03-09 v0.0.77

### Breaking
- Renamed `insert_into_editor` tool to `paste_into_editor`,
  requiring updates to user configuration and code references.

### Features
- Added `%{git_current_branch}` and `%{git_remote_origin}` placeholders
  to runtime info, available in prompt templates under a Git section.
- Added `%{time}` placeholder to the default prompt template.
- Updated the `GetCurrentWeather` tool description to explicitly
  mention a six-day forecast.

### Fixes
- Suppressed stderr output from Git commands during runtime info
  collection to prevent errors when running outside a Git repository.

### Improvements
- Reorganized the terminal information in the default prompt template
  under a unified **Terminal** heading.

## 2026-03-09 v0.0.76

### Features
- Added `client:` and `current_directory:` keys to `runtime_info_values`
  in `chat.rb`.
- Implemented `#client` method in `information.rb` to return the
  application name and version.
- Introduced helper `location_description?` in `location_handling.rb`.
- Added helper `disable_content_parsing` in `chat.rb` to manage content
  parsing state.
- Added new method `reload_default_persona` in `personae_management.rb`
  to prompt for confirmation before reloading the default persona file.

### Improvements
- Simplified `MessageList#to_ary` to return a duplicate of the internal
  array, removing automatic system prompt and location injection.
- Updated default config placeholders for `%{client}` and
  `%{current_directory}` in `default_config.yml`.
- Adjusted web searching logic to use `location_description?` instead of
  deprecated methods.
- Standardized JSON output formatting across tools to align keys, add
  spaces after commas, and include trailing commas.
- Standardized error field formatting to ensure consistent spacing and
  trailing commas.
- Refactored command handlers to call `disable_content_parsing` instead of
  assigning directly to `@parse_content`.
- Updated persona setup logic to trigger `disable_content_parsing` when a
  persona result is returned.
- Replaced flag `@persona_setup` with `@default_persona` in
  `personae_management.rb` and ensured it defaults to `:none`.
- Modified `clean` method to return the result of
  `reload_default_persona` for caller reaction.
- Adjusted `/clear` command handling to use the returned value from
  `clean` and proceed only when nothing is returned.
- Renamed local variable `runtime_info` to `runtime_info_values` in
  `chat.rb` for clarity.
- Updated runtime info prompt interpolation to use
  `runtime_info_values`.
- Added gems to `code_indexer` configuration in `.utilsrc`.

### Testing
- Removed tests that expected location-augmented system prompts from
  `spec/ollama_chat/message_list_spec.rb`.

## 2026-03-08 v0.0.75

### Breaking
- Renamed `import_url` tool to `get_url`: updated the config key,
  registration, class name `OllamaChat::Tools::GetURL`, and replaced
  all `chat.import` calls with `OllamaChat::Utils::Fetcher.get`.

### Features
- Added a `runtime_info` toggle switch and the `/runtime_info` command
  to display or inject runtime details (location, terminal size,
  time, voice, markdown status, and languages) into the chat prompt.
- Introduced a new `OllamaChat::Tools::ResolveTag` tool and
  `OllamaChat::Utils::TagResolver` utility to parse ctags files and
  resolve Ruby symbols to `file:line` locations.
- Added runtime reporting of tool allowed paths by introducing the
  `tool_paths_allowed` method and including its JSON output in the
  runtime information block and default config prompt.

### Fixes
- Added path validation and error handling to
  `OllamaChat::Tools::RunTests` via a new `check_path` method to
  prevent usage of `"./"` and validate existence; execution failures
  now return JSON with `error:` and `message:` keys.
- Normalized enabled-tool name lookup by converting the input to a
  string in `tool_enabled?`.
- Fixed a double-negative typo in the `insert_into_editor` tool
  description.

### Improvements
- Refined and unified tool descriptions across all tool definitions
  with consistent punctuation and clearer usage guidance.
- Improved persona loading and prompt formatting by updating
  `setup_persona_from_opts`, `info_persona`, and `load_persona_file`
  to return a `[pathname, content]` array, and adjusted
  `play_persona` to handle the new return value.
- Added an explicit confirmation step requiring user approval before
  applying edited persona configurations.
- Updated `OllamaChat::Tools::DirectoryStructure` description to note
  it can locate one or multiple files, referencing `max_depth`.
- Clarified usage of `browse`, `copy_to_clipboard`,
  `open_file_in_editor`, and `insert_into_editor` tools in
  documentation strings to specify they should only be invoked upon
  explicit user request.

### Testing
- Added spec tests for the new `ResolveTag` tool and updated
  `RunTests` specs to stub `check_path` and verify error handling for
  non-existent paths.
- Added test coverage for the `/runtime_info` toggle command and
  runtime information visibility.

## 2026-03-06 v0.0.74

### Breaking
- Removed the DWD weather sensor dependency and the `dwd_sensor.rb` file.
- The `get_current_weather` tool now requires the `PIRATEWEATHER_API_KEY` environment variable and no longer accepts `location` or `temperature_unit` arguments.
- The `/input` command now requires one or more space-separated glob patterns instead of a single pattern.

### Features
- Added a new `execute_ri` tool that looks up Ruby documentation using the `ri` command and returns the result as JSON.
- Refactored `OllamaChat::Tools::GetCurrentWeather` to use the Pirate Weather API for fetching weather data.
- Added support for multiple glob patterns to the `/input` command, allowing users to specify several search patterns.
- Improved model handling by pulling metadata during startup and disabling unsupported thinking or tool features automatically.

### Fixes
- Made `write_file` nil-safe by handling missing content gracefully.
- Fixed `write_file` to raise an `ArgumentError` for invalid modes and to treat `nil` mode as `overwrite`.
- Updated the gemspec to include new tool files and spec assets in the distribution list.

### Improvements
- Replaced `File.read(filename)` with `filename.read` for more idiomatic Ruby code.
- Removed the unnecessary `tins/secure_write` dependency.
- Extended `Fetcher.execute` to accept an array of strings for shell-safe command execution.

### Testing
- Added RSpec tests for the new `execute_ri` tool covering valid, missing, and invalid topics.
- Updated `write_file` tests to verify `ArgumentError` handling for invalid modes.
- Stubbed `get_weather_data` in tests and added the `pirateweather.json` asset.
- Adjusted directory structure and parsing specs to account for the new JSON asset.

## 2026-03-05 v0.0.73

### Breaking
- Renamed the `/regenerate` chat command to `/revise`, adding an optional `edit` subcommand for external editing.
- Replaced the `revise_last` method with `change_response` in the message editing logic.
- Modified `pull_model_unless_present` to return a `ModelMetadata` instance instead of a system prompt string.

### Features
- Introduced a `ModelMetadata` struct to encapsulate model information, including capabilities.
- Added a `can?` method to `ModelMetadata` to check for specific model capabilities.
- Displayed model capabilities in the session information output.
- Added support for editing the last response via the `/revise edit` command using a temporary file.

### Fixes
- Updated error recovery logic to disable both think mode and tool support when encountering bad request errors.
- Implemented `OllamaChat::UnknownModelError` to handle cases where a requested model is not found.

### Improvements
- Updated `use_model` to streamline model selection and metadata retrieval.
- Removed an unused parameter from the `pull_model_unless_present` method signature.

## 2026-03-04 v0.0.72

### Features
- Introduced `OllamaChat::PersonaeManagement` module and `/persona` command
  with subcommands `add`, `delete`, `edit`, `list`, `play`, `file`, `info`,
  and `load`.
- Added `-p` command-line option to load personas at startup.
- Added `/config reload` subcommand to prompt for confirmation, save the
  conversation, and restart the process via `exec`.
- Created `OllamaChat::Pager` module for centralized pager functionality.
- Created `OllamaChat::FileEditing` module and refactored `edit_config`,
  `compose`, and `revise_last` to use the new `edit_file` method.
- Added LLM-driven `insert_into_editor` tool with a new
  `perform_insert` method in `OllamaChat::FileEditing`.
- Enhanced `copy_to_clipboard` tool to accept an optional `text` parameter
  and added a `last_message_content` helper method.

### Fixes
- Modified `copy_to_clipboard` to return `true` upon successful copy
  operations instead of `nil`.
- Added `bytes_written` tracking to the `write_file` tool and corrected the
  return hash key.
- Added a `save_history` call after conversation backup to ensure history is
  persisted before restart.
- Renamed `choose_filename` to return a `Pathname` object instead of a `String`.

### Improvements
- Added a visual separator for tool output in the chat interface.
- Standardized type hints across the codebase, replacing generic Boolean
  comments with explicit `[ true, false ]` annotations.
- Refactored `OllamaChat::Tools::GetTime` to use a concise class definition
  style.
- Updated `ollama_chat.gemspec` file lists to include new modules and tools.

### Testing
- Added RSpec tests for the `insert_into_editor` tool.
- Updated `clipboard_spec.rb` and `copy_to_clipboard_spec.rb` to reflect
  new return values and parameters.
- Updated `input_content_spec.rb` and `message_editing_spec.rb` to account
  for `Pathname` returns and new error messages.

### Documentation
- Updated `README.md` and help messages to reflect new commands, options,
  and the `/config [edit|reload]` syntax.
- Added YARD documentation for the `reload_config` and `perform_insert`
  methods.

## 2026-02-26 v0.0.71

### Features
- Add `OllamaChat::Tools::CopyToClipboard` tool to copy the last
  assistant response to the system clipboard.
- Add `OllamaChat::Tools::PasteFromClipboard` tool to paste content from
  the system clipboard into the chat session.
- Replace the `/paste` command's input-based behavior with clipboard
  integration using `paste_from_clipboard`.
- Implement `MessageList#find_last` method with optional `content`
  parameter to filter messages.
- Add interactive help mode via the `/help me` command.
- Enable more tools by default, including `browse`, `read_file`,
  `write_file`, `directory_structure`, and `get_cve`.
- Add `require_confirmation` and `max_results` options for the
  `search_web` tool.
- Add `copy_to_clipboard` and `paste_from_clipboard` to default tool
  configurations.

### Improvements
- Rename `think_loud?` to `think?` in `FollowChat` for storage logic
  and update related display methods.
- Enhance `Clipboard#perform_copy_to_clipboard` and
  `Clipboard#perform_paste_from_clipboard` with improved error handling
  and documentation.
- Update success message for copy operations to "successfully copied to
  the system clipboard".
- Adjust `last_message_with_user` to conditionally include thinking
  content only when present.

### Fixes
- Fix `Pathname` object display in `save_conversation` and
  `load_conversation` by using `to_s.inspect` for consistent string
  quoting.
- Remove empty string output from `output_eval_stats` to reduce visual
  clutter.

### Testing
- Add test coverage for `CopyToClipboard` and `PasteFromClipboard`
  tools.
- Add test for saving conversations with thinking content.
- Update existing specs to reflect new clipboard methods and
  configuration changes.

## 2026-02-23 v0.0.70

### Features
- Added the `generate_password` tool to create secure random passwords with support for configurable alphabets and entropy.
- Added the `get_rfc` tool to retrieve RFC documents by ID from the RFC Editor website.
- Implemented a backup fallback mechanism to load the current conversation from `OC::XDG_CACHE_HOME` when the `-c` option is not provided.

### Improvements
- Renamed `OllamaChat::EnvConfig` to `OC` to simplify constant references and improve code readability.
- Added new configuration constants for `OC::OLLAMA::SEARXNG_URL`, `OC::OLLAMA::REDIS_URL`, and `OC::OLLAMA::REDIS_EXPIRING_URL`.
- Refactored code to use a nested class structure within the module for improved organization.
- Added comprehensive YARD documentation including `@param`, `@return`, and `@example` tags to tool classes.
- Updated `config_handling.rb` to save conversation backups to the XDG cache home directory instead of the current directory.
- Modified `message_list.rb` to use `FileUtils.rm_f` for safe backup file removal and consistent error string handling.

### Build & CI
- Updated the `tins` gem dependency to **1.52**.
- Removed the empty `lib/ollama_chat/tools/endoflife.rb` file as its functionality is provided by the `get_endoflife` tool.

### Testing
- Added comprehensive test suites for the `generate_password` and `get_rfc` tools.

## 2026-02-23 v0.0.69

### Features
- Added `on` and `off` options to the `/tools` command to enable or disable
  tools support globally.
- Added `OllamaChat::ConfigHandling` module to centralize configuration
  display, editing, and error handling logic.
- Added `tool_function`, `tool_configured?`, `tool_registered?`, and
  `tool_enabled?` helper methods to `OllamaChat::ToolCalling` for cleaner
  tool state management.
- Added `attr_reader` for `enabled_tools` in `OllamaChat::ToolCalling` to
  improve access to the list of active tools.

### Improvements
- Restructured the `tools` configuration to use `enabled` and `functions`
  keys, moving individual tool settings under `functions`.
- Refactored `Fetcher#fetch` to accept a single `opts` hash instead of
  separate `headers` and `options` arguments.
- Moved `model_with_size` and `choose_model` methods from
  `OllamaChat::Dialog` to `OllamaChat::ModelHandling`.
- Updated `OllamaChat::EnvConfig` and `OllamaChat::OllamaChatConfig` to
  consistently return `Pathname` objects for path-related methods.
- Reorganized access modifiers in multiple modules to mark helper methods as
  private, while keeping public interfaces intact.
- Updated tool implementations to use `config.tools.functions` for
  centralized configuration access.
- Guarded tool execution in `OllamaChat::FollowChat` to skip disabled tools
  and record appropriate error messages.

### Fixes
- Ensured `XDG_CONFIG_HOME` and `XDG_CACHE_HOME` paths are expanded to
  absolute paths using `Pathname#expand_path`.
- Corrected tool support status messages to use lowercase "support".

### Testing
- Updated spec files to use `.expose` on chat instances and modules to test
  newly private methods.
- Added `and_call_original` to source fetching tests to ensure proper method
  invocation.
- Adjusted `gem_path_lookup` spec to return a symbol for simplified
  assertions.

### Build & CI
- Updated development dependency `all_images` to **~>0.12**.
- Added `before` and `after` hooks to `.all_images.yml` to manage
  `Gemfile.lock` and display test results.
- Removed `gem update --system` and `gem install bundler gem_hadar` from the
  Dockerfile in `.all_images.yml`.
- Added `OLLAMA_CHAT_TOOLS_RUN_TESTS_TEST_RUNNER` to `.envrc` for the
  `run_tests` tool.

### Documentation
- Updated `README.md` to reflect the new `/tools` command options.

## 2026-02-19 v0.0.68

### Features
- Added `require_confirmation: true` option for the
  `open_file_in_editor` tool in the default configuration to
  provide an additional safety check.
- Introduced `OllamaChat::HTTPError` exception with a `status`
  attribute to support specific handling of non-200 HTTP responses.
- Added JSON serialization for directory structures in
  `OllamaChat::Parsing` using `generate_structure(file).to_json`.
- Updated tools (`get_cve`, `get_endoflife`, and `get_jira_issue`)
  to pass `reraise: true` to Excon for improved error propagation.

### Improvements
- Included `OllamaChat::Utils::AnalyzeDirectory` mixin in
  `OllamaChat::Parsing` and replaced fully-qualified
  `generate_structure` calls with local method invocations.
- Enhanced `OllamaChat::Utils::Fetcher` to handle the `reraise`
  option and raise `OllamaChat::HTTPError` on non-200 responses.
- Updated `AssetHelpers.asset` in `spec/spec_helper.rb` to accept
  an optional name parameter for flexible asset path resolution.

### Testing
- Added specs to verify that JSON output for directory structures
  contains expected file names in `spec/ollama_chat/parsing_spec.rb`.
- Added tests for `OllamaChat::Utils::Fetcher` to verify failure
  handling and `reraise` behavior.

## 2026-02-18 v0.0.67

### Features
- Add `max_depth` option to the `directory_structure` tool
- Attach `:depth` and `:height` metadata to directory entries
- Update `OllamaChat::Utils::AnalyzeDirectory#generate_structure`
  to support depth pruning

### Improvements
- Refactor `OllamaChat::Utils::AnalyzeDirectory` for better
  maintainability and clarity

### Testing
- Add test coverage for `max_depth` functionality
- Update `OllamaChat::Utils::AnalyzeDirectory` specs to
  handle module functions correctly

## 2026-02-16 v0.0.66

### Breaking
- Renamed tool class `OllamaChat::Tools::VimOpenFile` to
  `OllamaChat::Tools::OpenFileInEditor`, changed `register_name` from
  `vim_open_file` to `open_file_in_editor`, and updated
  `default_config.yml` to reflect the new tool name.

### Features
- Updated `OllamaChat::Tools::GetCurrentWeather.execute` to return a JSON
  string containing `current_time`, `measurement_time`, `temperature`, and
  `unit`.
- Updated `OllamaChat::Tools::ReadFile` to return a JSON string containing
  `path` and `content` instead of raw content.

### Improvements
- Changed `execute` in `OpenFileInEditor` to resolve `args.path` with
  `Pathname.new(...).expand_path` before calling `chat.vim.open_file`.
- Improved error handling in the weather tool by raising an exception when
  sensor measurements fail, resulting in consistent JSON error messages.
- Centralized tool call error handling by replacing `STDERR.printf` calls in
  `OllamaChat::FollowChat` with assignments to
  `@chat.tool_call_results[name]`.

### Documentation
- Added regular expression documentation in the `OllamaChat::Parsing` module
  for `CONTENT_REGEXP`.
- Enhanced documentation for the `fetch_issue` method in
  `OllamaChat::Tools::GetJiraIssue` with detailed parameter and return value
  descriptions.

### Testing
- Updated `spec/ollama_chat/tools/get_current_weather_spec.rb` to parse JSON
  output and assert on individual fields.
- Updated `spec/ollama_chat/tools/read_file_spec.rb` to parse JSON output and
  assert on `path` and `content` fields.
- Adjusted tool specifications to reference the renamed
  `open_file_in_editor` tool and expect corresponding behavior.

## 2026-02-10 v0.0.65

### Features
- Added new tool `GetTime` in `lib/ollama_chat/tools/get_time.rb` returning
  ISO8601 time.
- Enabled the `get_time` tool by default in `default_config.yml`.

### Improvements
- Removed `localtime` from `location_data` and the prompt template in
  `lib/ollama_chat/location_handling.rb`.
- Updated `default_config.yml` location prompt to exclude `on %{localtime}`.
- Simplified location switch messages in `lib/ollama_chat/switches.rb`.
- Updated `tools/get_location.rb` comments and description to reflect the
  removal of time data.
- Removed unused example code from `lib/ollama_chat/follow_chat.rb`.

### Testing
- Added `spec/ollama_chat/tools/get_time_spec.rb` for the new tool.
- Updated `spec/ollama_chat/message_list_spec.rb` and
  `spec/ollama_chat/tools/get_location_spec.rb` to match new prompt format
  and removed unused `time` field from `location_data` in tests.
- Added `get_time.rb` to `extra_rdoc_files` and `files` listings.
- Added `get_time_spec.rb` to `test_files` listing.

## 2026-02-09 v0.0.64

### Features
- Added new `OllamaChat::Tools::GetJiraIssue` tool for fetching JIRA issue information
- Introduced `ConfigMissingError` exception for handling missing configuration
- Added JIRA tool configuration in `OllamaChat::EnvConfig` with `URL`, `USER`,
  and `API_TOKEN` settings
- Updated `default_config.yml` to include `get_jira_issue` tool with
  `default: false`
- Updated tool registration to include the new `get_jira_issue` tool

### Improvements
- Enhanced `OllamaChat::Utils::Fetcher` to support additional options and
  middleware

### Testing
- Added comprehensive tests for the new `get_jira_issue` tool in
  `spec/ollama_chat/tools/get_jira_issue_spec.rb`
- Updated `directory_structure_spec.rb` to assert `json.size` is an `Integer`
  instead of a specific size threshold
- Updated `get_cve_spec.rb` to use keyword arguments in double definitions

## 2026-02-09 v0.0.63

### Breaking
- Renamed tool classes and files to more descriptive names, such as
  `OllamaChat::Tools::Browser` to `OllamaChat::Tools::Browse` and
  `OllamaChat::Tools::Grep` to `OllamaChat::Tools::ExecuteGrep`.
- Renamed the tool configuration option `confirm` to
  `require_confirmation` in `default_config.yml`.
- Simplified `OllamaChat::Tools::FileContext` to use only the glob `pattern`
  parameter, removing the `path` parameter.

### Features
- Added `OllamaChat::Tools::ImportURL` for fetching web content with a
  configurable URL scheme whitelist.
- Added `OllamaChat::Tools::SearchWeb` to perform web searches via configured
  search engines.
- Added `OllamaChat::Tools::FileWriter` for secure file operations with
  overwrite and append modes.
- Added `OllamaChat::Tools::FileReader` for reading file contents with path
  validation.
- Added `OllamaChat::Tools::RunTests` to execute RSpec or Test-Unit suites
  with optional coverage reporting.
- Added `OllamaChat::Tools::VimOpenFile` to open files in a remote Vim
  server with line range support.
- Added `OllamaChat::Tools::GemPathLookup` to find gem installation paths
  using Bundler.
- Added `OllamaChat::Tools::Browser` to open URLs in the user's default
  browser application.
- Added `ignore_case` flag to the `execute_grep` tool for case-insensitive
  matching.
- Added `OllamaChat::Utils::PathValidator` module with `assert_valid_path`
  helper and `OllamaChat::InvalidPathError` exception.
- Enhanced `OllamaChat::Vim` class with `open_file` and `server_running?`
  methods for file navigation.
- Added `valid_json?` method to `OllamaChat::Tools::Concern` for consistent
  JSON validation.

### Improvements
- Standardized tool execute methods to return JSON strings instead of mixed
  types.
- Improved tool execution flow in `OllamaChat::FollowChat` with better
  argument display and confirmation handling.
- Refactored `OllamaChat::Chat` initialization to use `default_enabled_tools`
  and add a `registered?` check to `OllamaChat::Tools`.
- Refactored system prompt setup logic into a dedicated
  `setup_system_prompt` method in `OllamaChat::Chat`.
- Added `OllamaChatError` base class for library-specific exceptions.

### Fixes
- Fixed `/last` command to prevent zero or negative values via clamping.
- Fixed message loading to handle missing `content` fields in JSON files.

### Testing
- Added comprehensive specs for all new tools including `import_url`,
  `search_web`, `file_writer`, `file_reader`, `run_tests`, `vim_open_file`,
  and `gem_path_lookup`.
- Updated existing specs to use the `json_object` helper for consistent JSON
  parsing.
- Updated specs to use `Dir.pwd` for asset paths in `execute_grep` tests.
- Added test for `ignore_case` behavior in `execute_grep` specs.
- Added test for invalid scheme rejection in `import_url` specs.
- Skipped pager test in non-TTY contexts.

### Documentation
- Added comprehensive documentation comments to `file_context` and
  `vim_open_file` tool methods.
- Enhanced documentation for `OllamaChat::Vim` class methods.
- Updated `OllamaChat::Tools::Browser` description to clarify functionality.
- Removed deprecated `extract_title_from_url` method from `SearchWeb`.

## 2026-02-07 v0.0.62

### Features
- Add a `path:` argument to the `file_context` tool to allow fetching the
  context for a single file directly.
- Display a busy indicator and status messages using the `infobar` gem while
  executing tools.
- Prompt the user for confirmation before executing `file_context` and
  `directory_structure` tools.
- Include a generated directory structure when a directory path is provided
  as file input during parsing.
- Move `generate_structure` into a new `OllamaChat::Utils::AnalyzeDirectory`
  module to support reuse in parsing and the `directory_structure` tool.

### Improvements
- Introduce `OllamaChat::Tools::Concern` to centralize tool registration
  logic and prevent duplicate registrations.
- Update `CVE`, `EndOfLife`, `Grep`, and `Weather` tools to catch all
  exceptions and return structured JSON errors.
- Improve `file_context` argument validation using `blank?` to treat empty
  strings consistently with `nil`.
- Add an `exclude:` option to the `directory_structure` tool, configurable
  via `default_config.yml`, to skip specific directories such as `corpus` and
  `pkg`.

### Fixes
- Skip unknown tools during execution in `OllamaChat::FollowChat` and log a
  warning to `STDERR`.
- Use `_1` instead of `it` in `OllamaChat::Utils::AnalyzeDirectory` to
  improve Ruby compatibility.

### Testing
- Add comprehensive specs for `AnalyzeDirectory` covering traversal,
  exclusions, and error handling.
- Add tests for exact `path` usage in `file_context` with conflict
  detection.
- Add tests for exception handling in `Grep` and `Weather` tools to verify
  structured JSON error responses.

### Build & CI
- Add `infobar` as a runtime dependency.
- Update `ollama_chat.gemspec` file lists to include new utilities, tests,
  and documentation.

## 2026-02-06 v0.0.61

### Features
- Added a new `OllamaChat::Tools::Grep` tool to enable grep command execution for file pattern searching.
- Configured the `execute_grep` tool with a `cmd` template and enabled by default.
- Utilized `Shellwords.escape` for secure argument handling in the new `Grep` tool.

### Improvements
- Refactored the `register` method in `OllamaChat::Tools` to consistently instantiate tool classes.
- Simplified the `DirectoryStructure` tool by removing the `depth` parameter from the tool signature.
- Updated `generate_structure` in `DirectoryStructure` to recursively build the directory structure without depth limits.
- Enhanced `DirectoryStructure` to skip symbolic links and hidden files during directory traversal.

### Testing
- Added comprehensive tests for the new `execute_grep` tool in `grep_spec.rb`.
- Updated `DirectoryStructure` tests to use only the `path` argument and verify default behavior.

### Build & CI
- Updated `ollama_chat.gemspec` to include `lib/ollama_chat/tools/grep.rb` and `spec/ollama_chat/tools/grep_spec.rb` in the distribution.

## 2026-02-06 v0.0.60

### Features
- Added `OllamaChat::Tools::DirectoryStructure` to retrieve
  directory hierarchies with configurable depth and hidden file
  skipping.
- Added `OllamaChat::Tools::FileContext` to generate file context
  data using glob patterns.
- Added `OllamaChat::LocationHandling` to manage location data
  and integrate it into system prompts.

### Improvements
- Updated `OllamaChat::InputContent#context_spook` to support
  dynamic output format conversion for **JSON** and **TOON**.
- Enhanced `OllamaChat::ToolCalling#list_tools` to display
  visual indicators for enabled and disabled tools.
- Refined `OllamaChat::Tools#register` to automatically
  instantiate tool classes.
- Modified `OllamaChat::FollowChat` to pass the chat instance
  to tool execution.
- Updated `OllamaChat::MessageList#at_location` to leverage the
  new location handling approach.
- Configured default tool states in `default_config.yml`.

### Build & CI
- Updated `ollama_chat.gemspec` to include new library and test
  files in package metadata.

### Testing
- Added test coverage for `DirectoryStructure`, `FileContext`,
  and `Location` tools.
- Updated `MessageList` and `InputContent` specs to support new
  functionality and assets.

### Documentation
- Added YARD documentation for location handling and new tool
  implementations.

## 2026-02-05 v0.0.59

### Features

- Add a `/tools` command to list, enable, or disable available tools
  dynamically during chat sessions.
- Implement the `OllamaChat::Tools` registry to manage tool registration and
  execution for `OllamaChat::Chat`.
- Add the `OllamaChat::Tools::Weather` tool to fetch real-time temperature
  data from the German Weather Service (DWD).
- Add the `OllamaChat::Tools::CVE` tool to retrieve security vulnerability
  details from the MITRE API.
- Add the `OllamaChat::Tools::EndOfLife` tool to query software lifecycle
  information from the endoflife.date API.
- Integrate tool calling support into `OllamaChat::Chat` and
  `OllamaChat::FollowChat` to handle tool execution and result formatting.

### Improvements

- Refactor tool management to use a dynamic `@enabled_tools` array instead of
  statically loading all configured tools at startup.
- Add configuration options for tool endpoints in `default_config.yml`.
- Implement caching for HTTP responses in the `OllamaChat::Utils::CacheFetcher`
  utility.
- Update the `OllamaChat::Tools::CVE` tool to use a consistent `url`
  configuration key instead of `url_template`.

### Build & CI

- Add the `rubyzip` gem as a runtime dependency for processing DWD weather
  data files.
- Update `ollama_chat.gemspec` to include new tool and specification files in
  the package.

### Testing

- Add RSpec tests for the new `OllamaChat::Tools::Weather`,
  `OllamaChat::Tools::CVE`, and `OllamaChat::Tools::EndOfLife` tools.
- Add tests for the `/tools` command handling in `OllamaChat::Chat`.

### Documentation

- Update `README.md` and `CHANGES.md` to document the new tool management
  features and built-in tools.

## 2026-02-02 v0.0.58

### Fixes
- Moved the API version check inside `connect_ollama` and changed
  it to raise a `RuntimeError` instead of an `ArgumentError`.
- Ensured `connect_ollama` resets `@server_version` before verifying
  the connection.

### Improvements
- Standardized YARD documentation formatting and leading spaces for
  continuation lines across multiple modules.
- Added missing documentation comments for the `base_url` and
  `connect_ollama` methods.
- Added the `utils` gem as a development dependency.
- Added `errors.lst` to `.gitignore` and the `Rakefile` packaging ignore
  list.

### Build & CI
- Updated the Redis image in `docker-compose.yml` to valkey **9.0.1**.

## 2026-01-21 v0.0.57

### Breaking
- Updated the configuration format to support nested `think` settings with `mode` and `loud` sub-properties.

### Features
- Introduced `OllamaChat::StateSelectors` module with `StateSelector` class for managing configurable states.
- Added `allow_empty` parameter to `StateSelector#initialize` to permit empty states in voice output.

### Improvements
- Replaced string-based document policy and think mode management with `StateSelector` objects.
- Refactored voice handling to use `StateSelector` for consistent configuration management.
- Updated command handlers to use `document_policy.choose` and `think_mode.choose` for state selection.

### Testing
- Added `state_selectors_spec.rb` to test the new `StateSelector` functionality.
- Updated existing tests to use `StateSelector` methods for document policy and think mode.

## 2026-01-17 v0.0.56

### Breaking
- Removed specialized CSV parsing functionality from the
  `OllamaChat::Parsing` module.

### Features
- Added `/reconnect` command to reset the Ollama connection by
  creating a new client instance.
- Updated `OllamaChat::InputContent#input` to select and read
  multiple files matching a glob pattern, concatenating their
  contents with filename headers.
- Added a `context` section to the default configuration with a
  `format: JSON` setting.
- Updated `context_spook` to pass the configured `format`
  parameter to `ContextSpook::generate_context` calls.
- Expanded context file inclusion to support YAML files in
  addition to Ruby files.

### Fixes
- Handled `nil` return values from `STDIN.gets` to prevent
  `NoMethodError` exceptions in `OllamaChat::Dialog`.

### Build & CI
- Updated `context_spook` dependency from version **1.1** to
  **1.5**.
- Updated `gem_hadar` development dependency from **2.16.3** to
  **2.17.0**.
- Updated `rubygems` version from **4.0.2** to **4.0.3**.

### Testing
- Updated test cases in `input_content_spec.rb` to verify
  multiple file selection behavior.
- Added test cases for the `/reconnect` command handling.
- Updated parsing tests to verify raw CSV content handling.

### Documentation
- Documented the new `/reconnect` command in `README.md` and
  in-app help messages.

## 2026-01-08 v0.0.55

### Features
- Added `OllamaChat::Vim` class for inserting text into Vim buffers
  using the clientserver protocol.
- Implemented `server_name` and `clientserver` attribute readers for the
  `OllamaChat::Vim` class.

### Fixes
- Corrected the "reqired" typo to "required" in the `ollama_chat_send`
  help text and `OllamaChat::InputContent` error messages.

### Improvements
- Enhanced error messages for missing vim server to include the specific
  server name being used.
- Added error handling to the `OllamaChat::Vim` `insert` method with a
  fallback to `STDERR` output when the vim command fails.

### Testing
- Added comprehensive specs for `OllamaChat::Vim` and `ThinkControl`
  modules, achieving 100% code coverage.

### Documentation
- Updated `README.md` and `OllamaChat::Information` to document the new
  `/revise_last` command.

## 2026-01-08 v0.0.54

### Features
- Added `/revise_last` command for editing the last message.
- Implemented `OllamaChat::MessageEditing` module with editor integration.

### Improvements
- Improved `InputContent` module with better error handling (replaced
  `$?` with direct `system` return).
- Updated `choose_filename` to use `_1` parameter for Ruby idioms.

### Testing
- Added comprehensive test suite for `InputContent` module with **100%**
  line coverage.
- Added comprehensive tests for `revise_last` functionality including
  editor requirements, message availability, and failure cases.

## 2026-01-07 v0.0.53

### Features
- Added `/compose` command to compose content using an external editor
  configured via the `EDITOR` environment variable.
- Added `compose` method to the `InputContent` module to open a temporary
  file in the editor for content creation.
- Added `OllamaChat::EnvConfig::EDITOR?` and
  `OllamaChat::EnvConfig::EDITOR!` methods for editor configuration access.
- Implemented graceful error handling for editor failures by returning `nil`
  and printing an error message to `STDERR`.
- Required the `tempfile` gem to support temporary file handling.

### Documentation
- Updated `README.md` and internal help text to include the new `/compose`
  command in the list of available chat commands.

## 2026-01-06 v0.0.52

### Improvements
- Enabled verbose context generation in `context_spook` to
  provide real-time feedback during context collection operations.

## 2026-01-06 v0.0.51

### Features
- Added `/input` command for selecting and reading file
  content via glob patterns.
- Added `/context` command to collect project context
  using the `context_spook` library.
- Implemented `OllamaChat::InputContent` module to
  handle file selection and context generation.
- Added `context_spook` **~> 1.1** dependency.

### Improvements
- Improved pipe command handling with dynamic
  command path resolution.
- Updated file checking to use `File.file?` instead
  of `File.stat`.
- Moved `RedisCache` class documentation to align
  with YARD conventions.
- Added YARD documentation for new input and context
  methods.

### Documentation
- Updated `README.md` and help text to document
  `/input` and `/context` commands.

### Testing
- Updated pipe command tests to use dynamic command
  path resolution.

## 2026-01-03 v0.0.50

### Features
- Added `OllamaChat::RedisCache` for Redis-backed caching with
  expiration and `Enumerable` support.

### Fixes
- Used `Pathname` in `attempt_to_write_file` to resolve paths correctly.
- Removed a duplicate `changelog` block from the `Rakefile`.

### Improvements
- Replaced `Documentrix::Documents::RedisCache` with
  `OllamaChat::RedisCache` in the `setup_cache` method.
- Integrated changelog generation into the `GemHadar` configuration.

### Build & CI
- Updated `valkey` image to version **8.1.5** for bug fixes.
- Updated `gem_hadar` development dependency to version **2.16.3**.
- Updated Ruby image tag to stable **4.0**-alpine.

### Testing
- Added test coverage for `OllamaChat::RedisCache` in
  `spec/ollama_chat/redis_cache_spec.rb`.
- Improved test setup for source fetching with explicit configuration.
- Updated test suite configuration for consistent default config usage.

## 2025-12-24 v0.0.49

### Breaking
- Updated the `unix_socks` dependency from **~> 0.2** to **~> 0.3**.
- Replaced `UnixSocks::Server` with `UnixSocks::DomainSocketServer` in
  `lib/ollama_chat/server_socket.rb`.

### Improvements
- Updated test expectations in `spec/ollama_chat/server_socket_spec.rb` to
  match the new class name.

### Build & CI
- Bumped `gem_hadar` development dependency from **>= 2.16.0** to **>=
  2.16.2**.

## 2025-12-23 v0.0.48

### Build & CI
- Updated the `unix_socks` runtime dependency to version **0.2.3**.

### Documentation
- Added changelog entry for **v0.0.48**.

## 2025-12-23 v0.0.47

### Features
- Handle existing socket file conflicts by prompting the user to
  remove stale files and retrying socket creation.

### Improvements
- Exit with an error code when the user declines to remove an
  existing socket file.

### Build & CI
- Include `CHANGES.md` in the gem distribution using `GemHadar`.
- Update the `unix_socks` dependency to require version **>=
  0.2.2**.
- Update the `gem_hadar` development dependency to version
  **>= 2.16.0**.

## 2025-12-20 v0.0.46

### Build & CI
- Changed `required_ruby_version` from `~> 3.2` to `>= 3.2` in both
  `Rakefile` and `ollama_chat.gemspec` to allow Ruby **3.2** and higher.
- Updated `tins` dependency from `~> 1.47` to `~> 1.51` in `Rakefile` and
  `ollama_chat.gemspec`.
- Added `bigdecimal` dependency with version `~> 3.1` to `Rakefile` and
  `ollama_chat.gemspec`.
- Updated `documentrix` dependency from `~> 0.0, >= 0.0.2` to `>= 0.0.4` in
  `Rakefile` and `ollama_chat.gemspec`.
- Updated `ollama-ruby` dependency from `~> 1.16` to `~> 1.19` in `Rakefile`
  and `ollama_chat.gemspec`.
- Updated `unix_socks` dependency from `~> 0.1` to `~> 0.2` in `Rakefile` and
  `ollama_chat.gemspec`.

### Testing
- Added `ruby:4.0-rc-alpine` image configuration to `.all_images.yml`.
- Changed `rake spec` to `bundle exec rake spec` in `.all_images.yml` to
  ensure consistent test execution.
- Updated test expectation in `follow_chat_spec.rb` to expect `puts` to be
  called with `("", "", /eval_duration/)`.

## 2025-12-10 v0.0.45

### Improvements
- Enhanced `OllamaChat::FollowChat` terminal output formatting
- Chomped content and thinking text in `OllamaChat::FollowChat` to
  prevent trailing whitespace
- Updated `display_formatted_terminal_output` in
  `OllamaChat::FollowChat` to accept an optional `output` parameter
- Routed markdown and non-markdown output through appropriate display
  methods in `OllamaChat::FollowChat#display_output`
- Added an extra blank line before evaluation statistics in
  `OllamaChat::FollowChat#output_eval_stats` for visual separation

### Build & CI
- Updated `bundle update` command to include the `--all` flag in
  `.all_images.yml`

## 2025-12-10 v0.0.44

### Fixes
- Fixed `stream` option in `spec/ollama_chat/follow_chat_spec.rb` from `on? true` to `on?: true`.

### Improvements
- Added `truncate_for_terminal` method to `OllamaChat::FollowChat` to limit output to terminal height.
- Extracted `prepare_last_message` and `last_message_with_user` methods for better code organization.
- Modified `FollowChat#process_response` to handle streaming and non-streaming display modes conditionally.
- Added `use_pager` method to `MessageList` to wrap large outputs with `Kramdown::ANSI::Pager`.

### Build & CI
- Updated `kramdown-ansi` dependency from **0.2** to **0.3** in `Rakefile` and `ollama_chat.gemspec`.

### Testing
- Added comprehensive tests for `truncate_for_terminal` covering various line count scenarios.
- Exposed the `FollowChat` instance in spec files to enable direct testing of new methods.

## 2025-12-09 v0.0.43

### Features
- Introduced `think_loud` switch to toggle thinking out loud annotations.
- Added `OllamaChat::ThinkControl` module to manage think mode settings.
- Added string modes `"low"`, `"medium"`, and `"high"` for the think feature.
- Added `/think_loud` command to toggle `think_loud` mode in the chat.
- Updated `FollowChat` to conditionally append thinking annotations based on `think_loud.on?`.

### Fixes
- Added retry logic in `interact_with_user` to handle `Ollama::Errors::BadRequestError` in think mode.

### Improvements
- Updated `ollama-ruby` dependency from version **1.14** to **1.16**.
- Updated `default_config.yml` to set `think_loud: true` by default.
- Simplified think mode handling and `think_show` output logic.
- Moved think mode methods from `OllamaChat::Dialog` to `OllamaChat::ThinkControl`.
- Updated documentation comments to follow new tagging conventions.

### Build & CI
- Added `lib/ollama_chat/think_control.rb` to gemspec file lists.

### Testing
- Updated tests to mock `think_loud` and verify annotation handling.
- Updated `follow_chat_spec.rb` to stub `think_loud?` instead of `think_loud.on?`.

## 2025-12-03 v0.0.42

### Fixes
- Resolved shell expansion issues in the voice list command by
  quoting the `?` argument in `default_config.yml`.
- Fixed JSON serialization errors for image data in Ollama messages
  by updating the `ollama-ruby` dependency.

### Improvements
- Replaced the hardcoded `my_pager` variable with a lookup using
  `OllamaChat::EnvConfig::PAGER?` to enable environment-based pager
  configuration.

### Build & CI
- Bumped the `ollama-ruby` gem dependency from **1.7** to **1.14**.

### Testing
- Added a spec for the `display_config` method in the
  `OllamaChat::Information` module.

## 2025-11-20 v0.0.41

### Features
- Added `clientserver` configuration option to `default_config.yml` with
  a default value of **socket**.
- Updated `OllamaChat::Vim` to accept a `clientserver` keyword argument
  in `initialize` and use the `--clientserver` flag in `insert` and
  `col` methods.
- Modified `OllamaChat::Chat` to pass the `clientserver` setting when
  creating a `OllamaChat::Vim` instance.

### Fixes
- Corrected `OllamaChat::MessageOutput` spec to expect
  `attempt_to_write_file` instead of `write_file_unless_exist`.

### Testing
- Removed a duplicate expectation in the `OllamaChat::MessageList`
  spec for `save_conversation`.

### Build & CI
- Updated gemspec and version constants to **0.0.41**.

## 2025-11-20 v0.0.40

### Improvements
- Improved `OllamaChat::Vim.default_server_name` to ensure
  uniqueness by using `File.basename` and `Digest::MD5.hexdigest`
- Refactored `OllamaChat::Vim#initialize` to call
  `self.class.default_server_name` instead of the instance method

### Documentation
- Enhanced documentation for `OllamaChat::Vim#initialize` and
  `OllamaChat::Vim.default_server_name`

## 2025-11-14 v0.0.39

### Features
- Added cross-platform clipboard support by replacing `pbcopy`
  with the `ctc` command.

### Build & CI
- Updated `tins` dependency from **1.41** to **1.47** in `Rakefile`
  and `ollama_chat.gemspec`.

## 2025-11-11 v0.0.38

### Features
- Added user confirmation prompts for the `/save` and `/output` commands
  before overwriting existing files.
- Replaced `write_file_unless_exist` with `attempt_to_write_file` in
  `OllamaChat::MessageOutput` to handle overwrite logic.

### Improvements
- Removed the `xdg` gem from the `code_indexer` dependencies in `.utilsrc`.

### Documentation
- Updated method documentation for `output` and `attempt_to_write_file` to
  reflect the new overwrite behavior.

## 2025-10-31 v0.0.37

### Features
- Use the XDG cache directory for chat history storage by default.

### Improvements
- Refactor system prompt selection logic in `change_system_prompt` to use
  a `case`/`when` statement.

### Build & CI
- Update `amatch` dependency constraint from `~> 0.4.1` to `~> 0.4`.
- Update `rubygems` version requirement from **3.6.9** to **3.7.2**.
- Update `gem_hadar` development dependency from **1.28** to **2.8**.
- Remove `.contexts` and `.github/workflows` files from the gem package.

## 2025-10-11 v0.0.36

### Features
- Reordered dialog menu prompts to place `[EXIT]` before `[NEW]` for
  improved default selection behavior.

### Improvements
- Replaced the `xdg` gem with direct XDG directory configuration using
  `EnvConfig::XDG_CONFIG_HOME` and `EnvConfig::XDG_CACHE_HOME`.
- Replaced explicit `it` parameter syntax with implicit `_1` in
  `decode` blocks to ensure compatibility with older Ruby versions.
- Added `openssl-dev` package to the Docker image build dependencies.

### Build & CI
- Updated the `valkey/valkey` Docker image version from **8.1.1** to
  **8.1.3**.
- Updated the `gem_hadar` development dependency to version **2.8**.
- Introduced a GitHub Actions workflow to deploy static documentation to
  GitHub Pages.
- Removed the deprecated `REDIS_EXPRING_URL` environment variable from
  `.envrc`.

### Documentation
- Added a link to the GitHub Pages documentation site in the README.
- Corrected YARD documentation guidelines for `initialize` methods.
- Updated documentation comments in `chat.rb` with consistent formatting.

## 2025-09-18 v0.0.35

### Breaking
- Removed support for Ruby **3.1**, now requiring **3.2** or later.

### Features
- Added `OllamaChat::EnvConfig` module to centralize environment
  variables using the `const_conf` gem.

### Fixes
- Updated regex pattern in `OllamaChat::Parsing` to match only escaped
  spaces in file paths.

### Improvements
- Replaced ad-hoc environment variable handling with `const_conf` for
  structured configuration management.
- Simplified `debug` method implementation by removing legacy debug flag
  handling.
- Refactored default configuration values in YAML files to use
  `const_conf` constants.

### Build & CI
- Added `const_conf (~> 0.3)` as a runtime dependency.
- Updated required Ruby version in `Rakefile` and `ollama_chat.gemspec`
  to `~> 3.2`.

### Testing
- Updated test suite to use `const_conf_as` helper and removed old ENV
  stubbing logic.

## 2025-09-17 v0.0.34

### Improvements
- Modified `-d` flag semantics to use working directory instead of runtime
  directory for socket path derivation
- Updated `send_to_server_socket` and `create_socket_server` methods to
  accept `working_dir` parameter
- Changed argument parsing in `ollama_chat_send` binary to utilize
  `working_dir` instead of `runtime_dir`

### Testing
- Added tests covering new `working_dir` functionality with default fallback
  to current directory

### Documentation
- Updated documentation and help text to reflect new `-d` option semantics

## 2025-09-15 v0.0.33

### Fixes
- Enhanced `CONTENT_REGEXP` to support escaped spaces in file paths.
- Modified `SourceFetching` module to properly unescape spaces using `gsub`.

### Testing
- Added a test case to verify parsing of file paths with escaped spaces.

## 2025-09-15 v0.0.32

### Fixes
- Fixed file path parsing to correctly handle `\ ` escaped
  spaces in relative paths by adding explicit unescaping.

## 2025-09-15 v0.0.31

### Features
- Added support for `file://` URIs and paths containing spaces or
  quotes using `URI.decode_www_form_component`.
- Introduced `check_exist:` option in `fetch_source` to validate file
  existence before fetching.
- Updated `parse_content` to use a new `CONTENT_REGEXP` for unified
  parsing of URLs, tags, and file references.

### Improvements
- Refactored `fetch_source` to handle relative, absolute, and tilde
  paths more robustly.
- Extracted file reading logic into a new private helper method
  `fetch_source_as_filename`.

### Build & CI
- Updated the `gem_hadar` development dependency from **2.3** to **2.6**.
- Added `ghostscript` to the Dockerfile dependencies.

### Testing
- Renamed the test asset `spec/assets/example with ".html"` to
  `spec/assets/example_with_quote.html` and updated related tests.
- Added `fail_fast: true` to the CI script configuration.
- Added a check for the `pbcopy` command in the clipboard spec to skip
  tests if unavailable.
- Wrapped the SimpleCov require in a `begin/rescue` block to handle
  `LoadError` gracefully.
- Set a default `OLLAMA_HOST` environment variable in the spec helper.
- Added comprehensive tests for parsing file paths with spaces, quotes,
  and encoding.

## 2025-09-11 v0.0.30

### Fixes
- Fixed logic in the web document handling branch to correctly assign
  `config.prompts.web_import` and `config.prompts.web_summarize`.
- Ensured the correct method, `import` or `summarize`, is invoked based
  on the configured `@document_policy`.
- Added `ask_and_send_or_self(:read)` calls within the processing blocks
  for both the default and summarizing branches.

### Build & CI
- Updated the `ollama-ruby` runtime dependency to version **1.7**.
- Updated the `kramdown-ansi` runtime dependency to version **0.2**.
- Added the `ruby:3.1-alpine` image to the CI pipeline configuration.
- Modified the CI script to update the Ruby `gem` system and install
  `bundler` explicitly.
- Replaced the removal of `Gemfile.lock` with a `bundle update` command
  for dependency management.
- Updated the `gem_hadar` development dependency to version **2.3**.

## 2025-09-08 v0.0.29

### Features
- Introduced document processing policies for web search results with
  `embedding`, `summarizing`, and `importing` modes.
- Added `@document_policy` configuration option to control the processing
  mode for web search results.
- Added automatic conversation backup saving in the `fix_config` method
  using **backup.json**.

### Improvements
- Refactored conversation persistence into a dedicated `OllamaChat::Conversation`
  module to simplify the `/save` and `/load` command implementations.
- Updated `/web` command help text to display the active document policy.
- Added `web_summarize` prompt template and updated `web_import` prompt
  to use plural "sources".

### Testing
- Updated socket configuration specs to reflect the `working_dir_dependent_socket`
  boolean flag and the new `ollama_chat-<hash>.sock` naming pattern.

### Build & CI
- Added `lib/ollama_chat/conversation.rb` to the gemspec files and
  `extra_rdoc_files` lists.

## 2025-09-08 v0.0.28

### Breaking
- Replaced `server_socket_runtime_dir` configuration option with `working_dir_dependent_socket`.

### Features
- Added return type documentation to `CacheFetcher#get` method.

### Fixes
- Resolved Unix socket path length issues by generating unique socket names using `Digest::MD5` based on the current working directory, following the format `ollama_chat-<hash>.sock`.

### Build & CI
- Updated `unix_socks` dependency constraint from `>= 0.0.1` to `~> 0.1` in both `Rakefile` and `ollama_chat.gemspec`.
- Added `.utilsrc` file to the `files` list in `ollama_chat.gemspec`.

## 2025-09-05 v0.0.27

### Fixes
- Fixed `OllamaChat::Utils::CacheFetcher` to return the `io` object,
  ensuring proper content type propagation to the caller.
- Updated `OllamaChat::Utils::Fetcher` to handle cache hit notifications
  with a fallback to `unknown` when the content type is missing.

### Build & CI
- Added `package_ignore` entries for configuration files such as
  `.envrc`, `.gitignore`, and `.github` to exclude them from the gem
  package.
- Reordered the file list in the gemspec to remove hidden files from
  the beginning of the array.
- Updated the `gem_hadar` development dependency from **2.1** to **2.2**.
- Added `.starscope.db` and `cscope.out` to `.gitignore` and the
  `Rakefile` ignore list.

## 2025-08-27 v0.0.26

### Features
- Added support for a numeric argument to the `/last` command, allowing users
  to specify the number of messages to display.
- Added a `/vim` command to insert the last message into a vim server.

### Fixes
- Added error handling to `init_chat_history` and `save_history` to gracefully
  handle failures during history persistence.
- Ensured `save_history` is called after clearing the command history, even
  when an error occurs.
- Removed a faulty `@see` documentation reference that caused crashes.

### Improvements
- Refactored `MessageList#show_last` to accept an optional count parameter and
  filter out user messages.
- Replaced environment variable mocking with `protect_env` and direct `ENV`
  manipulation for more robust testing.
- Modularized the spec helper into `AssetHelpers`, `StubOllamaServer`, and
  `ProtectEnvVars` modules for better organization.
- Improved the formatting and wording of cache hit messages in the infobar.
- Updated `gem_hadar` development dependency to **2.1** and included new
  context files in the gemspec.

### Documentation
- Added comprehensive YARD documentation for the `OllamaChat` namespace and
  major classes including `Chat`, `MessageList`, `DocumentCache`, and
  `FollowChat`.
- Documented the `OllamaChatConfig` class, detailing configuration paths and
  initialization examples.
- Added module-level documentation for `Parsing`, `Vim`, `MessageFormat`,
  `KramdownANSI`, `Information`, `UserAgent`, and `History`.
- Created YARD context files and guidelines to standardize documentation
  generation.

### Testing
- Added tests for the `/last` command variants, including cases with no
  argument and specific message counts.
- Added tests for the `last` method and `show_last` behavior when the message
  count exceeds the available messages.

## 2025-08-18 v0.0.25

### Features
- Added support for a runtime directory via a new `-d DIR` option in
  `ollama_chat_send`, allowing users to specify the location of the socket
  file for targeted message delivery.
- Refactored the `web` method in `chat.rb` to conditionally handle content
  based on embedding settings, using distinct `web_embed` and `web_import`
  prompt templates.

### Fixes
- Fixed `show_last` in `message_list.rb` to safely handle empty lists and
  prevent errors when no messages are present.
- Fixed `kramdown_ansi_parse` in `kramdown_ansi.rb` to return an empty string
  when `nil` is passed, preventing a `NoMethodError`.
- Adjusted cache retrieval logic in `fetcher.rb` to display the "getting from
  cache" message before the actual cache lookup occurs.

### Improvements
- Updated the `ollama-ruby` dependency constraint from `~> 1.2` to `~> 1.6`.
- Bumped the `tins` dependency from `~> 1.34` to `~> 1.41`.
- Added comprehensive documentation comments to the `OllamaChat::Clipboard`,
  `OllamaChat::Dialog`, `OllamaChat::Utils::Chooser`, and
  `OllamaChat::Utils::FileArgument` modules.

### Build & CI
- Integrated the `context_spook` gem as a development dependency.
- Added new context definition files: `.contexts/full.rb`,
  `.contexts/info.rb`, and `.contexts/lib.rb`.

### Testing
- Added new tests for `show_last` covering empty lists and message roles.
- Added tests for `kramdown_ansi_parse` to verify `nil` and empty string
  handling.
- Expanded `server_socket_spec.rb` to cover the new `runtime_dir` parameter.

## 2025-08-17 v0.0.24

### Improvements
- Updated `kramdown-ansi` dependency constraint from **0.0**
  to **0.1**.

## 2025-08-17 v0.0.23

### Features

- Added `OllamaChat::KramdownANSI` module to centralize `Kramdown::ANSI`
  parsing logic and style configuration within the `OllamaChat::Chat` class.
- Replaced direct calls to `Kramdown::ANSI.parse` with
  `@chat.kramdown_ansi_parse` in `FollowChat` and `MessageList` for consistent
  formatting.
- Added support for environment variables `KRAMDOWN_ANSI_OLLAMA_CHAT_STYLES`
  and `KRAMDOWN_ANSI_STYLES` to allow custom ANSI styling configuration.

### Fixes

- Resolved issue where file paths starting with `~` were not correctly
  expanded before existence checks in the parsing module.
- Added handling for `ArgumentError` exceptions caused by malformed file paths
  during content parsing.
- Escaped the dot in the regex pattern for image file matching in
  `parsing_spec.rb` to ensure accurate filename validation.

### Improvements

- Updated tests to mock `kramdown_ansi_parse` instead of relying on direct
  calls to `Kramdown::ANSI.parse`.

### Documentation

- Documented supported environment variables for configuration, including
  `KRAMDOWN_ANSI_OLLAMA_CHAT_STYLES` and `KRAMDOWN_ANSI_STYLES`.
- Provided example JSON format for customizing Markdown ANSI styles in the
  README.

## 2025-08-13 v0.0.22

### Features
- Added a new `-p` command line option to `ollama_chat_send` to enable
  source parsing of external resources.
- Enhanced the server socket communication to support passing a `parse`
  parameter for handling source resolution.

### Fixes
- Updated the `/drop` command to display only the last message using
  `show_last` instead of the last two messages.

### Improvements
- Improved documentation for the `server_socket.rb` methods with detailed
  parameter descriptions.

### Build & CI
- Updated the `gem_hadar` development dependency to version **2.0** and
  simplified the `SimpleCov` setup in the spec helper.

### Testing
- Added comprehensive tests for the new source parsing functionality in the
  server socket specs.
- Updated the chat spec to reflect the change in the `/drop` command
  behavior.

### Documentation
- Added documentation for the new `-p` flag in the README with example
  usage.
- Updated the CHANGES.md file with details on recent additions and
  improvements.

## 2025-08-11 v0.0.21

### Features
- Added Vim integration with a new `/vim` command to insert the last chat message into a running Vim server session at the current cursor position.
- Automatically select the available model without prompting when only a single model is present.

### Fixes
- Output save and load error messages to `STDERR` instead of `STDOUT`.
- Include the source identifier in the "invalid source" error message raised by `fetch_source`.
- Fixed DuckDuckGo search result handling to correctly add and return URL strings.

### Improvements
- Simplified `OllamaChat::Switches::Switch` initialization to accept direct boolean values, removing dynamic method dispatch.
- Added an `embedding_paused` switch to allow pausing and resuming embedding operations via configuration.

### Build & CI
- Added `lib/ollama_chat/vim.rb` to the gemspec `files` and `extra_rdoc_files` lists.

### Testing
- Added a second model entry to `spec/assets/api_tags.json` to support tests for multi-model selection scenarios.

## 2025-08-11 v0.0.20

### Fixes
- Fixed `output` to pass the message object to
  `write_file_unless_exist` for proper content writing.

### Documentation
- Added YARD-style documentation comments to public methods
  across `Dialog`, `DocumentCache`, `Information`,
  `MessageFormat`, `MessageOutput`, `ModelHandling`,
  `OllamaChatConfig`, and `Parsing`.

## 2025-08-11 v0.0.19

### Features
- Added `/last` command to display the last non-user message.
- Added `/output` and `/pipe` commands to save or pipe the last assistant
  response.

### Fixes
- Supported `application/xml` content type for RSS parsing.

### Improvements
- Sorted prompt lists for consistent ordering.
- Updated error message wording in the parsing module.
- Updated `MessageList#save_conversation` and `MessageList#load_conversation`
  to output errors to `STDERR` and return boolean success indicators.

### Testing
- Added test case for `application/xml` RSS parsing.
- Added test cases for `OllamaChat::MessageOutput` module.
- Removed `RSpec` prefix from `describe` blocks in favor of bare `describe`.

### Build & CI
- Updated `gem_hadar` development dependency from **1.23** to **1.27**.

### Documentation
- Updated `README.md` to document the new `/last`, `/output`, and `/pipe`
  commands.

## 2025-07-31 v0.0.18

### Features

- Added the `/prompt` command to prefill user input using
  `Reline.pre_input_hook` and the `choose_prompt` method in
  `lib/ollama_chat/dialog.rb`.
- Added model size display in the model selection menu using the new
  `model_with_size` method in `lib/ollama_chat/dialog.rb`.

### Improvements

- Updated voice list generation logic in
  `default_config.yml` to improve string handling and sorting efficiency.

### Build & CI

- Updated the `gem_hadar` development dependency constraint from **1.20**
  to **1.23**.

## 2025-07-14 v0.0.17

### Features
- Implement pager support for the list command, using `less` or
  `more` if conversation output exceeds terminal lines.
- Add tab-based command completion for chat input.

### Improvements
- Refactor `display_chat_help` to extract help text generation
  into a separate method.
- Prepend `?#` prefix to tag names in generated chat links.

### Build & CI
- Relax `xdg` runtime dependency from `~> 9.0` to `>= 0`.
- Update `unix_socks` runtime dependency to require `>= 0.0.1`.

### Testing
- Update message list specs to cover pager scenarios.

## 2025-07-10 v0.0.16

### Features
- Added a `-f CONFIG` option to the `ollama_chat_send` command to specify
  an external configuration file.
- Introduced the `server_socket_runtime_dir` setting in the default config,
  defaulting to the current directory to support per-directory server sockets.

### Improvements
- Refactored `OllamaChat::ServerSocket` to use a new `create_socket_server`
  helper that supports configurable runtime directories for Unix sockets.
- Updated evaluation rate metrics in `OllamaChat::FollowChat` to use `t/s`
  instead of `c/s` for better clarity.
- Added debug output in `OllamaChat::Chat` to log received server socket
  messages.

### Documentation
- Added YARD-style documentation for `initialize`, `call`, and `messages`
  methods in `OllamaChat::FollowChat`.

## 2025-07-02 v0.0.15

### Features
- Added support for Unix domain sockets using the `unix_socks`
  gem for server socket management.
- Enhanced `ollama_chat_send` with new command-line options:
  `-t` for terminal input, `-r` for waiting for server responses, and
  `-h` for usage information.
- Introduced `?selector` syntax for the `-m` and `-s` options to
  filter models and system prompts, opening a chooser dialog when
  multiple options match.
- Updated the `info` command output to display the connected Ollama
  server URL alongside the version.

### Fixes
- Refactored the `drop` method in `OllamaChat::MessageList` to
  correctly handle edge cases where the last message is a user message
  without a corresponding assistant response.

### Improvements
- Improved message processing logic in `OllamaChat::Chat` to handle
  different message types (`:socket_input`, `:terminal_input`, and
  `:socket_input_with_response`) and ensure proper socket cleanup.
- Updated `OllamaChat::ServerSocket` to use `UnixSocks::Server` for
  more robust socket initialization and message transmission.
- Added a `server_url` method to `OllamaChat::Information` to retrieve
  the base URL of the connected Ollama server.

### Build & CI
- Added `unix_socks` as a runtime dependency in the gemspec and
  Rakefile.

### Testing
- Updated `message_list_spec.rb` to test the new `drop` method
  behavior for incomplete exchanges.
- Updated `information_spec.rb` to verify `server_version` and
  `server_url` output.
- Set the `OLLAMA_CHAT_MODEL` environment variable in `chat_spec.rb`
  to ensure consistent test conditions.

### Documentation
- Added documentation for advanced `ollama_chat_send` parameters in
  the README.
- Documented methods in `OllamaChat::ModelHandling` and improved
  comments in `OllamaChat::ServerSocket`.
- Updated usage information in `OllamaChat::Information` and README
  to reflect the new `?selector` option.

## 2025-06-07 v0.0.14

### Features

- Added support for the `/system [show]` command to display the
  current system prompt without changing it.
- Added conversation length to the chat information display.
- Added a `thinking` status indicator to messages when the chat is
  in think mode.

### Fixes

- Fixed a potential error in `OllamaChat::SourceFetching` where
  document type concatenation could fail when `full?` returns `nil`.
- Updated chat content handling to encode with `invalid: :replace` to
  ensure UTF-8 validity and prevent encoding errors.

### Improvements

- Refactored `set_system_prompt` to remove existing system messages
  and allow clearing the prompt when `nil` or `false` is provided.
- Improved the clarity of the chat information display by updating
  labels for conversation and embedding models and restructuring
  voice and thinking status output.

### Testing

- Added and updated tests for conversation listing with and without
  thinking, and for setting system prompts when already configured.
- Updated `OllamaChat::Chat` and `OllamaChat::Information` specs to
  reflect changes in information display labels and command outputs.

### Documentation

- Updated `README.md` and command help text to document the new
  `/system [show]` option and updated `/clear` command arguments.
- Added YARD comments to `OllamaChat::History` methods and improved
  documentation for `OllamaChat::MessageList#set_system_prompt`.

## 2025-06-05 v0.0.13

### Features

- Added support for the `tags` option in the `/clear` command,
  allowing users to clear all tags in the documents collection.
- Applied `connect_timeout`, `read_timeout`, and `write_timeout`
  values from configuration to the `Ollama::Client` instance.
- Defined default `timeouts` in `default_config.yml` with
  `read_timeout` and `write_timeout` set to 300 seconds.

### Improvements

- Added YARD-style documentation comments to methods in
  `OllamaChat::Clipboard` and `OllamaChat::ServerSocket`.

### Documentation

- Updated the `/clear` command description in
  `information.rb` to reflect the new `tags` option.

## 2025-06-01 v0.0.12

### Breaking
- The `think_mode` setting has been replaced with a boolean `think`
  switch, requiring Ollama API version `0.9.0` or higher.

### Features
- Added `think` switch to toggle Ollama's native reasoning model
  support, which splits responses into `content` and `thinking`
  fields.
- Renamed `/think_mode` command to `/think` to toggle the thinking
  setting.

### Improvements
- Updated `OllamaChat::MessageType` module to
  `OllamaChat::MessageFormat` to support new thinking output
  formatting.
- Refactored `OllamaChat::FollowChat` to utilize the new
  `MessageFormat` methods for clearer terminal output.

### Build & CI
- Upgraded `ollama-ruby` dependency to **1.2** to support new API
  features.
- Updated Docker Compose configuration to use Valkey **8.1.1**.

### Testing
- Updated `FollowChat` and `Chat` specs to reflect the new `think`
  switch and `MessageFormat` implementation.

## 2025-06-01 v0.0.11

### Features
- Added a `think_mode` setting to control how internal reasoning
  blocks from models are handled, with options: `display`, `omit`,
  `only_delete`, and `no_delete`.
- Implemented the `/think_mode` command to interactively select and
  change the active think mode during a session.
- Added a `think_mode` chooser dialog for selecting from the
  available options.
- Updated the session information output to include the currently
  active think mode.
- Added `think_mode` to the default configuration with a value of
  `display`.

### Improvements
- Updated `OllamaChat::FollowChat` to render think blocks according
  to the selected mode, adding support for `omit_think_block` and
  `quote_think_tags` methods.
- Modified chat output to clear the screen and print user info before
  displaying new content in `OllamaChat::FollowChat`.
- Refactored `OllamaChat::Chat` to filter `think` blocks from
  conversation history before sending to the model, unless the mode
  is `no_delete`.

### Fixes
- Fixed the `/regenerate` command to correctly drop only one
  exchange when regenerating responses.
- Fixed a bug where the `query` value was not being assigned in the
  web search summarization flow.

### Testing
- Updated specs to verify think mode behavior in `OllamaChat::Chat`
  and `OllamaChat::FollowChat`.

### Documentation
- Updated the README and help text to document the `/think_mode`
  command and its available display options.

## 2025-05-28 v0.0.10

### Features
- Add support for sending content to the server socket with a
  specific type, defaulting to `socket_input`.

### Improvements
- Refactor chat input handling to use a centralized `handle_input`
  method, simplifying command processing logic.
- Prevent slash commands from being processed when input is received
  via `ollama_chat_send`, allowing raw content to be sent by default.

### Testing
- Expand test coverage for `OllamaChat::Chat`, including extensive
  tests for the `handle_input` method and various chat commands.
- Improve test coverage for `DocumentCache` and `Information`
  modules by exposing necessary methods for testing.

## 2025-05-26 v0.0.9

### Features
- Added a `-S` command-line option to enable server socket functionality
  for receiving input from `ollama_chat_send`.
- Updated `OllamaChat::Chat` to initialize the server socket only when the
  new option is provided.

### Improvements
- Improved tag parsing by adding regex validation for valid tags in
  `Documentrix::Utils::Tags`.
- Updated `parse_content` in `OllamaChat::Parsing` to use the new valid tag
  format and refined tag scanning logic.

### Build & CI
- Added a version constraint `>= 0.0.2` for the `documentrix` dependency in
  both the gemspec and Rakefile to ensure compatibility with the new tag
  parsing features.

### Documentation
- Updated the usage message in `README.md` and `information.rb` to include
  the new `-S` option.

## 2025-05-25 v0.0.8

### Features
- Introduce `fix_config` method to handle `ComplexConfig` errors.
- Prompt user to resolve config issues via a `DIFF_TOOL` command.
- Expose `default_config_path` and `diff_tool` in `OllamaChatConfig`.

### Fixes
- Catch `ComplexConfig::ConfigurationSyntaxError` in chat handling.
- Validate path existence for `OllamaChat::ServerSocket` to prevent overwrites.
- Clean up server socket files when the thread exits.

### Documentation
- Add `README.md` section on using `ollama_chat_send` to submit input.

## 2025-05-22 v0.0.7

### Features
- Added `ollama_chat_send` executable to send user input to the Ollama
  server via `OllamaChat::ServerSocket.send_to_server_socket`
  and handle exceptions.
- Added `OllamaChat::ServerSocket` module to manage a UNIX socket for
  receiving messages from external scripts during the interactive loop.
- Added support for loading and saving chat history using
  `File.secure_write`, with methods for initialization, saving, and
  clearing history.
- Enhanced `/clear` command to accept optional arguments
  (`messages`, `links`, or `history`) to clear specific types of data,
  defaulting to clearing messages.

### Fixes
- Updated `import_source` in `OllamaChat::SourceFetching` to safely
  handle `nil` values for `content_type` and improve display formatting.
- Rescued `Errno::ENOENT` in `OllamaChat::ServerSocket` to prevent
  unlinking warnings during socket cleanup.

### Improvements
- Refactored chat history management into a dedicated
  `OllamaChat::History` module included in `OllamaChat::Chat`.
- Changed chat history filename resolution to use the configuration
  setting first, falling back to the `OLLAMA_CHAT_HISTORY` environment
  variable.
- Updated `setup_cache` in `OllamaChat::Chat` to explicitly extract the
  expiry value from `config.redis.expiring.ex?`.
- Standardized command syntax in documentation and help output for
  `/clear`, `/collection`, and `/links` commands.

### Build & CI
- Added `ollama_chat_send` to the executable list in the Rakefile and
  gemspec.
- Updated `ollama_chat.gemspec` to include new library files in
  `extra_rdoc_files`.
- Updated Valkey container image to **7.2.9-alpine** in
  `docker-compose.yml`.

### Testing
- Added tests for chat history initialization, saving, and clearing
  functionality.
- Updated parsing spec to explicitly set document policy to `importing`
  and verify exact content match.
- Adjusted fetcher spec to account for trailing newline in echo output.

## 2025-04-15 v0.0.6

### Fixes
- Updated `model_present?` and `pull_model_from_remote` in
  `lib/ollama_chat/model_handling.rb` to use the new `ollama-ruby`
  **1.0** API by passing `model:` instead of `name:`.
- Modified `execute` in `lib/ollama_chat/utils/fetcher.rb` to append
  `2>&1` to commands to capture stderr output alongside stdout.

### Build & CI
- Upgraded the `ollama-ruby` runtime dependency from **0.15** to
  **1.0** in the `Rakefile` and `ollama_chat.gemspec`.

## 2025-03-22 v0.0.5

### Fixes
- Removed unnecessary parentheses from the `location` prompt template
  to prevent DuckDuckGo search errors.
- Added handling for `Ollama::Errors::TimeoutError` to display a message
  when the connection to the Ollama server is lost.
- Updated the chat statistics display logic to use the correct character
  for the separator.
- Improved mocking in web searching specs to use dynamic URLs and enabled
  deep freezing for `ComplexConfig` in tests.

### Features
- Added an attribute reader for `messages` and refactored internal usage
  to utilize the reader.
- Display the last exchange of a conversation when a session is loaded
  or started.
- Configured the default SearXNG URL to be fetched from the
  `OLLAMA_SEARXNG_URL` environment variable.
- Passed `embedding_length` from the configuration to `Documentrix`.

### Improvements
- Updated the `gem_hadar` development dependency to **1.20**.

## 2025-02-21 v0.0.4

### Features
- Added support for SearXNG and DuckDuckGo as pluggable web search
  engines via the new `web_searching` module.
- Added a `web_search` configuration block in `default_config.yml`
  to define the active engine and their respective search URLs.
- Added a `docker-compose.yml` service and configuration for running
  a local SearXNG instance.
- Display the current `ollama_chat` version in the information output.

### Fixes
- Fixed an issue where the `search_web` command would crash if
  the search engine returned no results.

### Improvements
- Changed the default Redis cache expiration time for chat documents
  to 0 to disable expiration by default.
- Refactored the `search_web` logic from `source_fetching.rb` to
  `web_searching.rb` to support multiple search engines.

### Build & CI
- Updated `.gitignore` and `Rakefile` to exclude SearXNG configuration
  files from packaging and version control.

### Testing
- Added `web_searching_spec.rb` to test search functionality for
  both DuckDuckGo and SearXNG.
- Updated `chat_spec.rb` to verify the new version and search engine
  information output.

## 2025-02-17 v0.0.3

### Features
- Add support for setting custom request headers via the `request_headers`
  configuration option to handle strict HTTP acceptance rules.
- Display the connected Ollama server version in the application output.

### Improvements
- Update the `ollama-ruby` dependency from **0.14** to **0.15**.
- Remove the `gem update --system` command and the explicit `bundler` gem
  installation from the Docker build process.
- Remove the `--full-index` flag from the `bundle install` command in
  CI scripts.

### Testing
- Introduce a `connect_to_ollama_server` helper in `spec_helper.rb` to
  centralize API request stubs for tags, show, and version.
- Update chat specifications to use the `test` collection to isolate them
  from the `default` collection.
- Add test fixtures for the Ollama API version endpoint.

### Build & CI
- Add the `yaml-dev` package to the Docker image build dependencies.
- Include `spec/assets/api_version.json` in the gem specification file list.

## 2025-02-12 v0.0.2

### Improvements
- Improved location handling in `MessageList` by adding a system prompt
  containing the assistant prompt and location when no system prompt was
  previously defined.
- Simplified configuration defaults by loading them from the new
  `default_config.yml` file instead of using the inline `DEFAULT_CONFIG`
  hash.

### Testing
- Updated `message_list_spec.rb` to cover the new behavior of adding a
  location system prompt when no explicit system prompt is defined.

### Documentation
- Added new entries to `CHANGES.md` documenting the improvements and
  configuration changes for version **0.0.2**.

## 2025-02-02 v0.0.1

### Features
- Added a Docker Compose setup for a local Valkey (Redis) development
  environment, including configuration and environment variable
  exports.

### Improvements
- Refactored `OllamaChat::Chat` to use instance variables for document
  storage and updated the `add_documents_from_argv` method to rely on
  internal state.
- Replaced manual boundary checks in source fetching with `clamp(1..)`
  to normalize the result count.
- Standardized user-facing messages for message removal to use "drop"
  terminology instead of "pop".
- Refactored switch access to use dedicated reader methods (`markdown`,
  `stream`, `voice`, etc.) instead of direct instance variable access,
  and updated `OllamaChat::FollowChat` to reference the parent chat
  object for switch states.

## 2025-01-29 v0.0.0

  * Start
