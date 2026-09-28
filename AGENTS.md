# Jeeves instructions

Keep designs, decisions, and research in [docs](docs/README.md).

Use `td` for local tasks, progress, blockers, and handoffs. In each new agent
context, run `td usage --new-session -q` once; use `td usage` for full workflow
guidance. Follow the [task workflow](docs/task-tracking.md), including first-time
setup. Keep GitHub Issues for shared scope and acceptance criteria; link related
issues from td.

Before non-trivial work or writing memory, search the relevant knowledge.
Use `bin/knowledge search "term"` for known terms and
`bin/knowledge query "question" --no-rerank` for broader questions.
Read focused results with `bin/knowledge get <path> -l 80`.
Use direct reads or `rg` for known paths or after a successful lookup with no
matches. Markdown source files are authoritative.
If configured QMD fails, report it to the user immediately and attempt repair.
If repair fails, pause knowledge-dependent work until the user approves a
fallback; never silently bypass broken QMD with `rg` or direct reads. Follow
the [search failure policy](docs/development-workflow.md#search-failures).

Follow the engineering policies linked below:

- Prefer fewer dependencies; justify additions by their concrete benefits
  under the [dependency policy](docs/development-workflow.md#third-party-dependencies).
- Cover regression fixes and functional changes with automated tests. Use
  [red-green TDD](docs/development-workflow.md#test-driven-development)
  when practical; explain exceptions. Test observable behavior through public
  interfaces, with fakes at external-system boundaries.
- Keep [test cost proportional](docs/development-workflow.md#test-cost-and-coverage)
  while preserving coverage, independence, and useful complete journeys.
- Keep [files cohesive](docs/development-workflow.md#file-organization);
  approximately 1,000 lines is a review threshold for source, tests, and styles.
- Keep [Markdown pages focused](docs/development-workflow.md#markdown-pages)
  on one topic or reader task, without numeric size limits.
- Isolate [validation inputs and output](docs/development-workflow.md#validation-checkout-isolation)
  to the active checkout.
- Declare supported [runtime and toolchain versions](docs/development-workflow.md#runtime-and-toolchain-versions)
  and keep development, CI, and deployment compatible.


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

Follow the [memory](memory/README.md) and [docs](docs/README.md) formats.
Keep accepted decisions separate from proposals. Preserve unrelated changes.
Keep secrets and generated caches out of Git.

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
- Nonfunctional changes, including docs, task tracking, and comments, may be
  committed and pushed without a version bump or gem release. Run the checks
  appropriate to the change; an explicit release request still applies.
- Keep errors and progress on stderr; piped input and dry-run print only the message.
- Git failures must stop the operation, and dry-run must not alter the real index.
- Test actual Git workflows in temporary repositories and fake HTTP only at the network boundary.
- Do not use arbitrary sleeps in tests. Use bounded synchronization when testing concurrent behavior.
