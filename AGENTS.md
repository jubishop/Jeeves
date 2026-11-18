# Jeeves instructions

<!-- project-starter:begin -->
Project Starter manages this block; add project rules after it. Project rules
take precedence over this block and the foundation pages wherever they differ.

- Keep durable guidance and non-derivable context in [memory](memory/README.md),
  and designs, decisions, and research in [docs](docs/README.md). Before
  non-trivial work or writing memory, search with `bin/knowledge search "term"`
  or `bin/knowledge query "question" --no-rerank`, then read results with
  `bin/knowledge get <path> -l 80`. Markdown sources are authoritative.
- If configured QMD fails, follow `~/AGENTS.md` for a failed knowledge search,
  repairing it as
  [search failures](docs/foundation/knowledge-search.md#search-failures)
  describes.
- Follow the [engineering policy](docs/foundation/engineering-policy.md):
  fewer dependencies, red-green tests for behavior changes, cohesive files and
  pages, checkout-isolated validation, and the latest stable toolchains.
- Run [checks](docs/foundation/engineering-policy.md#checks) by change:
  `bin/check --documents-only` for text, the relevant checks while editing
  code, and `bin/check --full` before merging or releasing production code
  unless an enforced CI gate runs it. Reuse passing results.
- Keep accepted decisions separate from proposals, and keep generated caches
  out of Git. Keep secrets out of public repositories only; a private one may
  commit them.
- Run `bin/setup` after cloning, `bin/doctor` to diagnose setup, and
  `bin/qmd-index` after uncommitted knowledge edits. Managed files listed in
  `.project-starter.json` change only through Project Starter or a recorded
  override with its reason.
<!-- project-starter:end -->

## Jeeves

Jeeves is a Ruby CLI that writes conventional commit messages with gitmoji
through OpenRouter, the Anthropic API, or local Ollama models. Its bundled
prompt is sarcastic; users can customize a global or repository prompt.

- Read [the architecture](docs/architecture.md) before changing generation or
  Git behavior, and [configuration](docs/configuration.md) for provider,
  model, and prompt settings.
- Run `bundle exec rake test`, or one test file, and `bundle exec rake lint`
  for Ruby changes; `bundle exec rake build` builds the gem into `gems/`.
  `bin/check --full` runs all three through `bundle exec rake validate`.
- Publish the gem or push functional changes only when asked. Nonfunctional
  changes, such as docs and comments, may be pushed without a version bump or
  gem release.
- Keep errors and progress on stderr; piped input and dry-run print only the
  message.
- Git failures must stop the operation, and dry-run must not alter the real
  index.
- Test actual Git workflows in temporary repositories, and fake HTTP only at
  the network boundary.
- Never use arbitrary sleeps in tests; use bounded synchronization for
  concurrent behavior.
