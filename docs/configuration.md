---
status: current
---

# Configuration

Jeeves supports OpenRouter and local Ollama models. Your shell supplies the
settings; Jeeves does not load `.env` files itself.

## Provider and model

| Variable | Purpose | Default |
| --- | --- | --- |
| `GIT_COMMIT_PROVIDER` | `openrouter` or `ollama` | `openrouter` |
| `GIT_COMMIT_MODEL` | OpenRouter model | `x-ai/grok-code-fast-1` |
| `GIT_COMMIT_LOCAL_MODEL` | Installed Ollama model tag | `gemma4:26b` |
| `OPENROUTER_API_KEY` | Required for OpenRouter only | None |
| `OLLAMA_HOST` | Ollama HTTP or HTTPS endpoint | `http://127.0.0.1:11434` |
| `GIT_COMMIT_LOCAL_CONTEXT` | Local context window in tokens | `65536` |
| `GIT_COMMIT_MAX_DIFF_BYTES` | Maximum diff bytes sent to the model, including omission notices | `65536` |
| `GIT_COMMIT_MESSAGE_FORMAT` | `conventional` or `plain` | `conventional` |

`--provider` and `--model` override saved settings for one command. `--local`
is shorthand for `--provider ollama`. Cloud and local model settings remain
separate, so switching providers does not erase either model choice.

For fish, save your choice in shell configuration or an environment file
that your shell loads. For example:

```fish
set -Ux GIT_COMMIT_PROVIDER ollama
set -Ux GIT_COMMIT_LOCAL_MODEL your-installed-model
```

For bash or zsh, add the equivalent exports to your shell startup file:

```sh
export GIT_COMMIT_PROVIDER=ollama
export GIT_COMMIT_LOCAL_MODEL=your-installed-model
```

An exported variable from another configuration source takes precedence over
a fish universal variable. Edit the source you already use rather than
maintaining conflicting settings.

## Local setup

Install [Ollama](https://ollama.com/download), start its server, and pull a
model from the [model library](https://ollama.com/library). On macOS:

```sh
brew install ollama
brew services start ollama
ollama pull your-chosen-model
```

Use the exact installed tag in `GIT_COMMIT_LOCAL_MODEL`. MLX packages require
Apple Silicon. Model size, active parameter count, quantization, prompt size,
and output length all affect latency. Measure representative diffs on the
actual machine; an online token-speed benchmark is not a local latency test.
See [local model selection](local-model-selection.md) for measurements on an
M5 Pro Mac with 64 GB memory and the tested tradeoffs.

Ollama listens on localhost by default. For local-only operation, set
`{"disable_ollama_cloud": true}` in `~/.ollama/server.json` and restart Ollama.
See the [Ollama FAQ](https://docs.ollama.com/faq). Jeeves sends no cloud API key
to Ollama, bypasses environment HTTP proxies for local requests, and never
falls back to OpenRouter after an Ollama failure.

## Prompts and tone

Prompt lookup uses this order:

1. `.jeeves_prompt` at the Git repository root.
2. `~/.config/jeeves/prompt`.

Jeeves copies the bundled `config/prompt` only when generation needs a global
prompt and none exists. Updating the package does not overwrite an existing
personal prompt. Help and version commands do not create configuration.

The bundled prompt keeps Jeeves' sarcastic roast. For neutral messages, change
its Tone section to:

```text
Tone:
- Use factual, neutral language. Do not roast, insult, joke, or use sarcasm.
```

Keep the literal `{{DIFF}}` placeholder. Jeeves inserts the diff without
interpreting backslashes. Instructions ask for factual descriptions, a short
subject, and a body proportional to the change. They prohibit fabricated
motives, test results, and features. Repository code and comments are data,
not instructions to the model.

See [the repository prompt example](../example.jeeves_prompt) for a neutral
JavaScript-specific variant.

## Output checks and large diffs

The default format requires a conventional subject such as
`fix(client): preserve zero retries`. Jeeves supplies or corrects its gitmoji
from the type and separates the body with a blank line without another model
call. It rejects empty messages, leaked
reasoning, control characters, malformed subjects, and output-limit truncation.
It cannot verify that a model understood the code correctly. Use `--dry-run`
to inspect a message before committing when needed.

For a custom prompt that intentionally produces another subject format, set
`GIT_COMMIT_MESSAGE_FORMAT=plain`. Empty output, reasoning, and control
characters are still rejected.

Jeeves automatically shortens oversized diffs for either provider. It first
removes unchanged context lines. If more reduction is needed, it shares space
across files and hunks, keeping file metadata and hunk headers where they fit.
Small changes can remain complete while large hunks keep excerpts from their
start and end. When even the headers do not fit, it keeps excerpts from the
start and end of the diff. Very long lines can be cut within a line, but UTF-8
characters remain intact.

Every shortened input includes a notice for the model that content is missing
and hunk ranges refer to the original diff. A warning on stderr reports the
original and shortened byte counts. Stdout still contains only the generated
message in piped and dry-run modes. Shortening uses no extra model calls.
Omitted content can cause the message to miss changes. Use `--dry-run` to
review it, split the changes, or increase the limits to include more detail.

For Ollama, the default context is 65,536 tokens. Jeeves retains the conservative
estimate of one byte per token and reserves 1,000 output tokens and 256 tokens
for chat framing. It subtracts the selected prompt's size, including repeated
`{{DIFF}}` placeholders, before fitting the diff. The smaller of this available
space and `GIT_COMMIT_MAX_DIFF_BYTES` controls shortening. A prompt or limit
that leaves too little room for useful excerpts and notices still returns an
actionable error. Increasing the context can use more model memory.

Jeeves reads the complete diff before shortening, including piped input, so
later files can receive space. The byte setting limits model input, not process
memory. Only the text sent to the model is shortened: staged content, committed
files, and Git's checks for concurrent changes are preserved.

Local generation requests thinking off. Models that ignore this request and
return reasoning are rejected. Network connection timeout is five seconds;
response timeouts are 60 seconds for OpenRouter and 300 seconds for Ollama.
These are failure bounds, not performance promises. Loading a model and large
inputs can take longer than an ordinary warm request.
