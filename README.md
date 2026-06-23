# OllamaChat - Ruby Chat Bot for Ollama

## Description

**ollama_chat** is a chat client, that can be used to connect to an ollama
server and enter chat conversations with the LLMs provided by it.

## Documentation

Complete API documentation is available at: [GitHub.io](https://flori.github.io/ollama_chat/)

## Installation (gem)

To install **ollama_chat**, you can type

```
gem install ollama_chat
```

in your terminal.

## Configuration

### Environment Variables

The following environment variables can be used to configure behavior:

#### Ollama Core
- `OLLAMA_URL` - Base URL for Ollama server (default: `http://localhost:11434`)
- `OLLAMA_HOST` - Base hostname for Ollama server (default: `localhost:11434`)
- `OLLAMA_SEARXNG_URL` - SearxNG search endpoint URL

#### Chat Settings
- `OLLAMA_CHAT_MODEL` - Default model to use (e.g., `llama3.1`)
- `OLLAMA_CHAT_SYSTEM` - Default system prompt file or content
- `OLLAMA_CHAT_COLLECTION` - Default collection for embeddings
- `OLLAMA_CHAT_HISTORY` - Chat history filename
- `OLLAMA_CHAT_USER` - Full name of the chat user
- `OLLAMA_CHAT_DEBUG` - Debug mode toggle (1 = enabled)

#### Tool Configuration
- `OLLAMA_CHAT_TOOLS_TEST_RUNNER` - Configured test runner for `run_tests` (default: `rspec`)
- `OLLAMA_CHAT_TOOLS_CTAGS_TOOL` - Path to the ctags tool
- `OLLAMA_CHAT_TOOLS_TAGS_FILE` - Location of the tags file
- `OLLAMA_CHAT_TOOLS_PATCH_TOOL` - Patch tool to use
- `OLLAMA_CHAT_TOOLS_JIRA_URL` - Base URL for Jira instance
- `OLLAMA_CHAT_TOOLS_JIRA_USER` - Username for Jira authentication
- `OLLAMA_CHAT_TOOLS_JIRA_API_TOKEN` - API token for Jira authentication
- `OLLAMA_CHAT_TOOLS_IMAGE_GENERATOR_URL` - Base URL for ComfyUI server
- `OLLAMA_CHAT_TOOLS_IMAGE_GENERATOR_WORKFLOW` - ComfyUI workflow as JSON string
- `OLLAMA_CHAT_TOOLS_IMAGE_GENERATOR_PROMPT_NODE_ID` - Prompt node ID
- `OLLAMA_CHAT_TOOLS_IMAGE_GENERATOR_FILENAME_PREFIX_NODE_ID` - Filename prefix node ID
- `OLLAMA_CHAT_TOOLS_PIRATEWEATHER_API_KEY` - Pirate Weather API key

#### System & Infrastructure
- `XDG_CONFIG_HOME` - XDG Configuration home directory
- `XDG_CACHE_HOME` - XDG Cache home directory
- `XDG_STATE_HOME` - XDG State home directory
- `PAGER` - Default pager for output
- `EDITOR` - Default text editor
- `BROWSER` - Default web browser
- `DIFF_TOOL` - Tool for diff operations (default: `vimdiff`)
- `KRAMDOWN_ANSI_OLLAMA_CHAT_STYLES` - Custom ANSI styles for Markdown formatting
- `KRAMDOWN_ANSI_STYLES` - Fallback ANSI styles configuration
- `OLLAMA_REDIS_URL` - Redis connection URL for documents (documentrix)
- `OLLAMA_REDIS_EXPIRING_URL` - Optional Redis connection URL for caching

Example usage for `KRAMDOWN_ANSI_OLLAMA_CHAT_STYLES`:

```bash
# Set custom ANSI colors for Markdown output as a JSON object:
export KRAMDOWN_ANSI_OLLAMA_CHAT_STYLES='{"header":["bold","on_color241","white"],"strong":["bold","color76"],"em":["italic","color227"],"code":["bold","color214"]}'
```

## Usage

It can be started with the following arguments:

```
Usage: ollama_chat [OPTIONS]

  -f CONFIG      config file to read
  -l SESSION     load session with name/id SESSION
  -n             create a new session
  -u URL         the ollama base url, OLLAMA_URL
  -m MODEL       the ollama model to chat with, OLLAMA_CHAT_MODEL, ?selector
  -c CHAT        a saved chat conversation to load
  -C COLLECTION  name of the collection used in this conversation
  -D DOCUMENT    load document and add to embeddings collection (multiple)
  -M             use (empty) MemoryCache for this chat session
  -E             disable embeddings for this chat session
  -S             open a socket to receive input from ollama_chat_send
  -V             display the current version number and quit
  -h             this help

  Use `?selector` with `-m` or `-l` to filter options. Multiple matches
  will open a chooser dialog.
```

The base URL can be either set by the environment variable `OLLAMA_URL` or it
is derived from the environment variable `OLLAMA_HOST`. The default model to
connect can be configured in the environment variable `OLLAMA_CHAT_MODEL`.

The YAML config file is stored in `$XDG_CONFIG_HOME/ollama_chat/config.yml` and
you can use it for more complex settings.

### Example: Using a Persona

You can import a persona profile from a Markdown file and load it into the
current session. The persona's content is then interpolated into the system
prompt (which defaults to `"%{persona}"`) as `%{persona}`. You can set your own
system prompts and interpolate the persona like this:

```
You are a helpful assistant.

%{persona}
```

The following interaction demonstrates how to import a persona file, activate
it, and start the conversation:

```
$ ollama_chat
Connecting to llama3.1@http://localhost:11434 now…
Type /help to display the chat help.
📨 user:
/persona import config/sherlock.md
# (Prompts for name: "sherlock")
Persona 'sherlock' imported successfully.
📨 user:
/persona
# (Select 'sherlock' from the list to be impersonated by the assistant)
📨 user:
Good morning.
📨 assistant:
Ah, good morning, my dear fellow! It is a pleasure to make your acquaintance. I
am Sherlock Holmes, the renowned detective, and this is my trusty sidekick, Dr.
Watson. Please, have a seat, and tell us about the nature of your visit. What
seems to be the problem that has brought you to our humble abode at 221B Baker
Street?
```

### Example: Using a multimodal model

This example shows how an image like this can be sent to the LLM for multimodal
analysis:

![cat](spec/assets/kitten.jpg)

```
$ ollama_chat -m llava-llama3
Model with architecture llama found.
Connecting to llava-llama3@http://localhost:11434 now…
Type /help to display the chat help.
📸 user> What's on this image? ./spec/assets/kitten.jpg
📨 assistant:
The image captures a moment of tranquility featuring a young cat. The cat,
adorned with gray and white fur marked by black stripes on its face and legs,
is the central figure in this scene. Its eyes, a striking shade of blue, are
wide open and directed towards the camera, giving an impression of curiosity or
alertness.

The cat is comfortably nestled on a red blanket, which contrasts vividly with
its fur. The blanket, soft and inviting, provides a sense of warmth to the
image. In the background, partially obscured by the cat's head, is another
blanket of similar red hue. The repetition of the color adds a sense of harmony
to the composition.

The cat's position on the right side of the photo creates an interesting
asymmetry with the camera lens, which occupies the left side of the frame. This
visual balance enhances the overall composition of the image.

There are no discernible texts or other objects in the image. The focus is
solely on the cat and its immediate surroundings. The image does not provide
any information about the location or setting beyond what has been described.
The simplicity of the scene allows the viewer to concentrate on the main
subject - the young, blue-eyed cat.
```

### Using `ollama_chat_send` to send input to a running `ollama_chat`

You can do this from the shell by pasting into the `ollama_chat_send`
executable.

```
$ echo "Why is the sky blue?" | ollama_chat_send
```

To send a text from inside a `vim` buffer, you can use a function/leader like
this:

```
map <leader>o :<C-U>call OllamaChatSend(@*)<CR>

function! OllamaChatSend(input)
  let input = "Take note of the following code snippet (" . &filetype . ") **AND** await further instructions:\n\n```\n" . a:input . "\n```\n"
  call system('ollama_chat_send', input)
endfunction
```

#### Advanced Parameters for `ollama_chat_send`

The `ollama_chat_send` command now supports additional parameters to enhance
functionality:

- **Terminal Input (`-t`)**: Sends input as terminal commands, enabling special
  commands like `/input`.

  ```bash
  $ echo "/input https://example.com/some-content" | ollama_chat_send -t
  ```

- **Wait for Response (`-r`)**: Enables two-way communication by waiting for
  and returning the server's response.

  ```bash
  $ response=$(echo "Tell me a joke." | ollama_chat_send -r)
  $ echo "$response"
  ```

- **Source Parsing (`-p`)**: Enables automatic parsing of URLs, file paths, and
  similar tokens in input content. When enabled, the system will attempt to
  resolve and include external resources.

  ```bash
  $ echo "Visit https://example.com for more info" | ollama_chat_send -p
  ```

- **Working Directory (`-d`)**: Specifies the working directory used to derive
  the Unix socket file path. When the ollama chat configuration is set to use
  a working directory dependent socket (via `working_dir_dependent_socket: true`),
  this option determines the base path for socket naming. If not specified, the
  current working directory is assumed.

  ```bash
  $ echo "Hello world" | ollama_chat_send -d /tmp/my_working_dir -r
  ```

- **Help (`-h` or `--help`)**: Displays usage information and available options.

  ```bash
  $ ollama_chat_send -h
  ```

These parameters provide greater flexibility in how you interact with
`ollama_chat`, whether from the command line or integrated tools like `vim`.

## Available Tools

The assistant can interact with the system using a variety of tools to gather
context, manipulate files, and retrieve external information.

| Category | Tools | Description |
| :--- | :--- | :--- |
| **Filesystem** | `read_file`, `write_file`, `patch_file`, `delete_file`, `move_file`, `directory_structure`, `execute_grep` | Read, write, and search files within allowed directories. |
| **Ruby/Dev** | `resolve_tag`, `execute_ri`, `gem_path_lookup`, `run_tests`, `eval_ruby` | Introspect Ruby code, check documentation, and run test suites. |
| **Web/External** | `search_web`, `get_url`, `browse`, `get_rfc`, `get_cve`, `get_endoflife`, `get_ghr`, `get_jira_issue` | Access the internet, fetch specific URLs, and look up technical standards. |
| **System/Util** | `get_time`, `get_location`, `get_current_weather`, `generate_password`, `compute_bmi`, `roll_dice` | General utility functions for time, location, and simple calculations. |
| **Editor/Clip** | `copy_to_clipboard`, `paste_from_clipboard`, `paste_into_editor`, `open_file_in_editor` | Bridge the gap between the chat and the system clipboard or editor. |
| **Knowledge** | `retrieve_document_snippets`, `file_context` | Semantic search for specific snippets vs. broad retrieval of structured project context. |
| **Multimodal** | `generate_image` | Generate images via a local ComfyUI server. |

***Note on Knowledge Tools**: Use `retrieve_document_snippets` for precise,
low-token semantic discovery and `file_context` for a comprehensive view of
modules or patterns. Be cautious with broad patterns in `file_context`, as
importing too many files can exceed the LLM's context window.*

## Download

The homepage of this app is located at

* https://github.com/flori/ollama_chat

## Author

<b>OllamaChat</b> was written by [Florian Frank](mailto:flori@ping.de)

## License

This software is licensed under the [MIT License](./LICENSE).
