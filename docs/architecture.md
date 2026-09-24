---
status: current
---

# Architecture and Git behavior

Jeeves is a small Ruby CLI. Git commands, prompt handling, output validation,
and provider HTTP clients have separate responsibilities.

## Components

| Component | Responsibility |
| --- | --- |
| `bin/jeeves` | Load the library and return the CLI exit status |
| `lib/jeeves.rb` | Parse options and coordinate the workflow |
| `lib/jeeves/settings.rb` | Resolve and validate environment settings |
| `lib/jeeves/git_repository.rb` | Run Git, preview changes, commit, and push |
| `lib/jeeves/prompt.rb` | Select, install, and render prompts |
| `lib/jeeves/message.rb` | Validate output and normalize gitmoji |
| `lib/jeeves/providers.rb` | OpenRouter and Ollama HTTP requests |
| `lib/jeeves/runtime.rb` | Enforce supported Ruby versions |

The provider clients use Ruby's HTTP and TLS libraries. There is no agent
framework or model SDK dependency. Model calls do not execute tools.

## Modes

- Plain `jeeves` reads the staged diff, generates a message, and commits it.
- `--all` stages working-tree changes first. A staging failure stops the run.
- `--dry-run` prints a message and leaves the index and HEAD unchanged.
- `--all --dry-run` stages into a disposable alternate index to preview all
  changes, including untracked files, without changing the real index.
- Piped input generates a message and performs no stage, commit, or push.
- `--push` runs only after a successful commit. A push failure returns an error
  while preserving the successful local commit.

All Git commands use argument arrays, not shell interpolation. Every failure
stops the workflow with a nonzero status and an error on stderr. Generation
status also uses stderr; piped and dry-run stdout contains only the message.

Before generation, Jeeves records the staged tree and HEAD. It checks them
again immediately before committing, so an index or HEAD change while waiting
for the model aborts the commit. Git hooks still run normally and may affect
Git's behavior. Commit message files use unique temporary paths with automatic
cleanup, including when Git fails.

## Testing boundaries

CLI tests use the public `CLI#run` interface and stub HTTP at the network
boundary. Workflow tests launch the real executable in isolated repositories
with a local HTTP fixture. They exercise failed staging, failed hooks, push
failures, successful local pushes, prompt precedence, first-run installation,
unborn repositories, index changes during generation, and paths with spaces.

Tests do not call private methods or replace project logic. Test fixtures
have isolated home directories, Git configuration, temporary paths, and ports.
No tests use production providers, credentials, repositories, or remote pushes.
See [the development workflow](development-workflow.md) for commands and
validation requirements.
