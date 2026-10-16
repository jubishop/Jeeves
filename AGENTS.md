# Jeeves instructions

<!-- project-starter:begin -->
Project Starter manages this block; add project rules after it. Project rules
take precedence over this block and the foundation pages wherever they differ.

- Keep durable guidance and non-derivable context in [memory](memory/README.md),
  and designs, decisions, and research in [docs](docs/README.md). Before
  non-trivial work or writing memory, search with `bin/knowledge search "term"`
  or `bin/knowledge query "question" --no-rerank`, then read results with
  `bin/knowledge get <path> -l 80`. Markdown sources are authoritative.
- If configured QMD fails, tell the user immediately and attempt repair. If
  repair fails, pause knowledge-dependent work until the user approves a
  fallback; never silently substitute `rg` or direct reads. See
  [search failures](docs/foundation/knowledge-search.md#search-failures).
- Use td for work with multiple stages, interruptions, blockers, or handoffs;
  run `td usage --new-session -q` once per new context and keep handoffs
  current. See [task tracking](docs/foundation/task-tracking.md).
- Follow the [engineering policy](docs/foundation/engineering-policy.md):
  fewer dependencies, red-green tests for behavior changes, flaky tests fixed
  or tracked in an issue, cohesive files and pages, checkout-isolated
  validation, and the latest stable toolchains.
- Deliver by [kind of change](docs/foundation/engineering-policy.md#kinds-of-change):
  commit text, such as Markdown and AI skill prose, directly on the default
  branch without checks; commit development code, such as tests, CI, and
  tooling, directly after its checks pass; and deliver production code through
  a pull request after its checks.
- Run [checks](docs/foundation/engineering-policy.md#checks) by change: the
  relevant checks while editing, and `bin/check --full` before merging or
  releasing production code unless an enforced CI gate runs it. Reuse passing
  results.
- Keep accepted decisions separate from proposals, preserve unrelated changes,
  and keep generated caches out of Git. Keep secrets out of public
  repositories only; a private one may commit them.
- Run `bin/setup` after cloning, `bin/doctor` to diagnose setup, and
  `bin/qmd-index` after uncommitted knowledge edits. Managed files listed in
  `.project-starter.json` change only through Project Starter or a recorded
  override with its reason.
<!-- project-starter:end -->

## Jeeves

Jeeves is a Ruby CLI for conventional commit messages with gitmoji. It uses
OpenRouter or local Ollama models. The bundled prompt is sarcastic; users can
customize their own global or repository prompt.

- Read [the architecture](docs/architecture.md) before changing generation or Git behavior.
- Read [configuration](docs/configuration.md) for provider, model, and prompt settings.
- Use [GitHub Issues](https://github.com/jubishop/Jeeves/issues) for tracked work.
- Run `bundle exec rake test` for Ruby changes, or a focused test file.
- Run `bundle exec rake lint` for Ruby lint checks.
- Run `bundle exec rake build` to build the gem into `gems/`.
- `bin/check --full` runs `bin/check-application`, which runs
  `bundle exec rake validate` after the foundation checks.
- Do not publish a gem or push changes unless requested.
- Nonfunctional changes, including docs, task tracking, and comments, may be
  committed and pushed without a version bump or gem release. Run the checks
  appropriate to the change; an explicit release request still applies.
- Keep errors and progress on stderr; piped input and dry-run print only the message.
- Git failures must stop the operation, and dry-run must not alter the real index.
- Test actual Git workflows in temporary repositories and fake HTTP only at the network boundary.
- Do not use arbitrary sleeps in tests. Use bounded synchronization when testing concurrent behavior.
