# Jeeves instructions

Keep durable guidance and non-derivable context in [memory](memory/README.md).
Keep designs, decisions, and research in [docs](docs/README.md). Use the
project's chosen task tracker for work items and implementation progress.

Before non-trivial work or writing memory, search the relevant knowledge.
Use `bin/knowledge search "term"` for known terms and
`bin/knowledge query "question" --no-rerank` for broader questions.
Read focused results with `bin/knowledge get <path> -l 80`.
Use direct reads or `rg` for known paths or after a successful lookup with no
matches. Markdown source files are authoritative. Update existing pages when possible.
If configured QMD fails, report it to the user immediately and attempt repair.
If repair fails, pause knowledge-dependent work until the user approves a
fallback; never silently bypass broken QMD with `rg` or direct reads. Follow
the [search failure policy](docs/development-workflow.md#search-failures).

Prefer fewer third-party dependencies. Use standard libraries, platform APIs,
or a focused implementation owned by the project when they meet its needs at
a reasonable maintenance cost. Add a dependency when its concrete benefits
justify it; initial implementation convenience alone is not enough. Apply
the [dependency policy](docs/development-workflow.md#third-party-dependencies)
through ordinary technical judgment, without a separate approval step.

Regression fixes and functional changes require automated tests for the
changed behavior. Use red-green test-driven development (TDD) whenever
practical: prove a focused test fails before implementation and passes after.
If testing first is not practical, explain why and how the behavior was
verified. Follow the [testing workflow](docs/development-workflow.md#test-driven-development).

Test user-visible outcomes, public interfaces, and interactions with external
systems. Put fakes at external-system boundaries so real project logic runs.
Do not test private helpers or internal structure, expose private functionality,
or add production APIs only for tests. Tests should allow internal refactoring
that preserves behavior.

Prepare unrelated test prerequisites through isolated fixtures or existing
public interfaces. Use the least costly test level that proves the required
behavior, retaining complete journeys and interaction-specific coverage.
Measure before adding parallel execution and preserve test independence.
See [test cost and coverage](docs/development-workflow.md#test-cost-and-coverage).

Keep files focused on one coherent responsibility. Use approximately 1,000
lines as a review threshold for hand-written source, tests, and styles, not
a hard cap. Prefer cohesive extraction; do not compress formatting or create
arbitrary fragments to meet a count. Larger files are acceptable when splitting
would reduce clarity. See [file organization](docs/development-workflow.md#file-organization).

Keep memory, docs, and other Markdown pages focused on one topic or reader
task. When extending a long page, review its scope and split independent
topics into linked pages when that improves reading and maintenance. Use
the [Markdown guidance](docs/development-workflow.md#markdown-pages), without numeric size thresholds.

Scope project source discovery and mutable validation output to the active
checkout. Exclude nested worktrees and temporary copies; include required
generated inputs deliberately. `.gitignore` does not control every tool's
discovery. Follow [checkout isolation](docs/development-workflow.md#validation-checkout-isolation).

Declare supported runtime and toolchain versions and keep development, CI,
and deployment compatible with that policy. Application commands should reject
unsupported versions before work starts. Prefer maintained releases and
coordinate upgrades. See [runtime and toolchain versions](docs/development-workflow.md#runtime-and-toolchain-versions).

Run `bin/setup` after cloning. Choose checks for the changed files: use
`bin/check --documents-only` for Markdown edits and `bin/check` for foundation
checks only. Keep application tools out of both modes; run relevant application
checks explicitly for code edits.
Run `bin/check --full` locally after setup, test/build infrastructure changes,
or when focused checks leave material uncertainty. Require successful full
validation before merge or release. An enforced full CI gate can supply that
result for ordinary code changes; otherwise run the full check locally before
delivery. Do not run checks for discussion or read-only work. Batch edits
before checking; reuse passing results while relevant inputs are unchanged.
See [the workflow](docs/development-workflow.md#checks-and-project-extensions).
Use `bin/doctor` to inspect local setup and `bin/qmd-index` to refresh search
after uncommitted knowledge edits when current search results are needed.
Hooks refresh search after Git events.

Read the relevant memory or docs index for its format and maintenance rules.
Keep accepted decisions separate from proposals. Preserve existing project
instructions, setup commands, hooks, and unrelated changes when adapting this
foundation. Keep secrets and generated caches out of Git.

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
- Do not publish a gem or push changes unless requested.
- Keep errors and progress on stderr; piped input and dry-run print only the message.
- Git failures must stop the operation, and dry-run must not alter the real index.
- Test actual Git workflows in temporary repositories and fake HTTP only at the network boundary.
- Do not use arbitrary sleeps in tests. Use bounded synchronization when testing concurrent behavior.
