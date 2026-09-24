---
status: current
---

# Development workflow

This repository keeps knowledge as Markdown and uses optional QMD search.
Each checkout has its own index. Git hooks refresh it in the background.

## First setup

Run from the repository root:

```sh
bin/setup
bin/doctor
bin/check --full
```

Setup requires Git and Python 3.9 or later. Checks also require ShellCheck,
available through the operating system's package manager. QMD and direnv are
optional. Missing optional tools produce clear notices; an installed but
failing QMD returns an error. Install QMD using its
[official instructions](https://github.com/tobi/qmd#installation).
The starter records its tested QMD version in `.project-starter.json`.

Setup validates configuration, activates bundled hooks when no existing
integration would be displaced, prepares caches, and waits for the initial
index refresh. QMD may download local models on first use. Rerunning setup
preserves existing choices and skips indexing when inputs are unchanged.

The bundle omits `.envrc`. Create it only when the project needs environment
settings, and review it before running `direnv allow`. QMD does not need direnv
or shell-wide environment exports. Preserve useful existing environment
settings when adapting setup; remove an obsolete QMD-only file.

## Runtime and toolchain versions

Declare the supported versions of the runtimes, compilers, and build tools
the project uses. Keep local development, CI, and deployment compatible with
that declaration. Use the stack's existing manifests, version files, and
setup tools where practical; avoid conflicting declarations.

Application commands should stop before installation, tests, builds, or
service startup when the active versions are unsupported. Report the detected
version, the supported range, and how to select a compatible toolchain.
Keep document and foundation checks independent of application runtimes they
do not use.

Prefer recent maintained releases. Where an ecosystem offers a long-term
support channel, prefer it unless the project has a reason to choose another
supported channel. Upgrade deliberately after dependency and behavior checks,
coordinating development, CI, and deployment. Do not let an unbounded version
selector silently change the supported major release. This foundation does
not select an application language, version, package manager, or deployment
platform.

## Search

From the root, use `bin/knowledge`. Setup also creates a repository-local
`git knowledge` alias when that name is free, so the command works from any
subdirectory. An existing alias is preserved.

```sh
git knowledge search "worktree" -c docs
git knowledge query "how should decisions be recorded" --no-rerank
git knowledge get qmd://docs/development-workflow.md -l 80
git knowledge context list
```

Choose keyword search for names and known terms. Use a semantic query for
broader questions. Read a focused source page before relying on a result.
Source Markdown remains authoritative. Known-file reads and broader source
searches after a successful lookup with no matches remain appropriate. Follow
the [failure policy](#search-failures) when a configured lookup fails.

The command supplies QMD configuration, cache, and database paths only to
the QMD process. It does not change the shell's cache directory or depend on
personal shell wrappers. It refuses named indexes to keep checkout isolation.
If an executable must be selected explicitly, use an absolute local setting:

```sh
git config --local knowledge.qmdPath /absolute/path/to/qmd
```

The shared `.config/knowledge.json` defines Markdown collections, exclusions,
and short descriptions attached to search results. The helper renders an
ignored `.config/qmd/index.yml` with absolute paths. Change the shared JSON,
then refresh; direct QMD collection/context edits to the generated file will
be replaced. The starter supports `**/*.md` collection patterns.

## Optional home memory

Home notes are excluded by default. Opt in through local Git configuration:

```sh
git config --local knowledge.homeMemoryPath /absolute/path/to/personal/notes
bin/qmd-index
```

This setting is shared by linked worktrees but is not committed. Notes are
indexed locally, not copied into the project. Missing directories produce
a notice. To remove the collection:

```sh
git config --local --unset knowledge.homeMemoryPath
bin/qmd-index
```

## Refresh and recovery

`post-checkout`, `post-commit`, `post-merge`, and `post-rewrite` hooks request
background refreshes. The foreground command is:

```sh
bin/qmd-index
```

Git hooks do not run on every file save. Run this command after uncommitted
knowledge edits when current search results matter. It waits for the requested
refresh and returns its success or failure. Every knowledge lookup verifies
source, configuration, database presence, and successful refresh state before
returning results. Stale or unknown inputs trigger a coordinated refresh.
Refresh messages go to stderr so JSON output remains valid. Unchanged inputs
reuse the existing index and embeddings.

Automatic refresh waits up to 60 seconds. Set a positive local
`knowledge.searchRefreshTimeout` value in seconds when a project needs a
different bound. A timeout returns an error without results; the background
worker may still finish. Use `bin/doctor` and the foreground refresh to inspect
and recover. Explicit foreground refreshes can wait for larger indexing jobs.

Results are buffered until QMD succeeds and freshness is checked again. If
sources change during the lookup, discard the results and return an error.
This verifies indexed inputs and completed refresh state, not the semantic
quality of search results or the internal integrity of the SQLite database.

One worker serves each checkout. It hashes indexed Markdown and configuration,
including optional home notes, to skip unchanged inputs. Bursts of requests
share the worker. If inputs change during indexing, the worker runs another
pass. QMD itself handles incremental index and embedding updates. A failed
update does not start embedding. Git does not wait for indexing to finish.

Freshness includes the QMD release version, including prerelease and build
metadata. It excludes the optional Git commit suffix in `qmd --version`, which
can identify an unrelated surrounding repository. QMD subprocesses do not
inherit Git repository selectors from hooks. Diagnostics retain the full
reported version. After replacing a custom QMD build without changing its
release version, run `bin/qmd-index --force`.

Use `bin/qmd-index --force` to rebuild even when recorded inputs match.
Inspect `.cache/qmd/index.log` after failure. Logs rotate at approximately
1 MB on worker start, retaining one previous file. A stopped worker releases
its operating-system lock; rerun the foreground command to recover. Avoid
direct `qmd update` and `qmd embed`, which bypass this coordination.

### Search failures

When configured QMD fails, immediately tell the user what failed. Run
`bin/doctor`, inspect the refresh log, and attempt a focused repair. Verify
recovery by repeating the failed lookup successfully. Do not report success
from a command that returned an error, timed out, or discarded stale results.

If repair fails, pause knowledge-dependent work until the user explicitly
approves a fallback. Do not silently substitute `rg`, direct Markdown reads,
another index, or a different search tool to bypass the failure. Unrelated
work may continue when it does not depend on the missing knowledge.

A successful lookup with no matches is not a tool failure. Reading known
files and broadening that successful search remain allowed. A project may
deliberately operate without optional QMD, but its absence or failure does
not establish that decision; use an existing explicit project choice or ask
the user. Keep the Markdown source usable in that approved mode.

## Worktrees

After the repository has a commit:

```sh
git worktree add -b feature-name worktrees/feature-name
```

The first checkout prepares the worktree. `bin/prep-worktree` can repeat the
preparation. It discovers worktrees through Git, supports separate Git metadata,
and keeps databases under each checkout's `.cache/qmd/index.sqlite`. Preparation
records the verified primary path in local `knowledge.primaryWorktree` to
support Git layouts whose worktree listing exposes only the metadata path.
Rerun preparation in the primary checkout after moving it.

All projects and worktrees share model files at `~/.cache/qmd/models`.
This fixed path is independent of `XDG_CACHE_HOME`. Each checkout links its
`.cache/qmd/models` there; its index stays in `.cache/qmd/index.sqlite` inside
that checkout. Setup creates the shared directory. With QMD installed, initial
embedding downloads a missing embedding model there; query expansion and
reranking download their models on first use. Existing files are reused.

Setup and refresh migrate old caches. They verify file contents before removing
identical copies from a checkout-local directory. Conflicting filenames or
unexpected entries stop migration without deleting those files. Inspect the
reported paths before retrying. An old symlink is replaced, but its external
target is retained because other consumers may still need it. Remove redundant
external copies only after verifying their contents and redirecting all users.
Do not delete `~/.cache/qmd/models` when cleaning up a repository or worktree.

A linked worktree's `.envrc` is approved automatically only when its bytes
match a primary checkout file that direnv already reports as allowed.
Ordinary branch switches do not approve changed environment files. Bare
repositories have no primary environment file to inherit trust from.

After moving a checkout, use Git's worktree repair procedure if required,
then inspect `bin/doctor`. Run `bin/prep-worktree` to repair a broken model
link and restore the fixed shared cache. Existing indexes remain local.

Remove worktrees only after checking for uncommitted and unpushed work.
Use `git worktree remove` and verify the resulting `git worktree list`.

### Validation checkout isolation

Scope project-source discovery for builds, static analysis, formatting, and
tests to the active checkout. Exclude nested worktrees, temporary copies, and
unrelated generated output. Include required generated sources or metadata
explicitly. Review each tool's discovery rules; Git ignore rules alone do not
establish this boundary.

Keep mutable test data, services, and build output separate between concurrent
checkouts. Immutable dependencies or caches may be shared where the tool
supports it safely. Preserve intentional cross-project checks with explicit
inputs instead of broad recursive scans.

When changing discovery or cache configuration, verify that errors in intended
project files are still detected and invalid files in an unrelated checkout
are not included. Check fresh and warm caches, including after an unrelated
checkout is added, changed, or removed. Investigate stale results and document
recovery; do not hide project errors through broad exclusions.

## Existing hooks

Setup does not overwrite a different active `core.hooksPath` or bypass
executable hooks in the default Git hooks directory. The agent applying this
foundation must integrate with the existing manager's supported entry points.

Each of the four post-event hooks must call `bin/knowledge-hook`, passing the
event name and original arguments. For a shell-based post-commit hook, the
added call is:

```sh
repo_root=$(git rev-parse --show-toplevel) || exit 1
"$repo_root/bin/knowledge-hook" post-commit "$@"
```

Use the actual event name in each file. The helper does not read stdin, so
existing post-rewrite input remains available. Preserve the existing hook's
exit status, argument handling, order requirements, and normal behavior.
Place the call before an existing unconditional `exit`, or integrate it through
the manager's own configuration. Do not append code that can never execute.

After integration:

```sh
git config --local knowledge.hooks external
bin/setup
```

Verify each event in a disposable checkout appropriate to the project. Check
that both the existing hook behavior and knowledge refresh occur, including
post-rewrite stdin and nonzero existing-hook exit codes. `bin/doctor` reports
which forwarding events it has observed in this checkout and their timestamps.
Observations are evidence of past runs, not proof that a later hook edit works.

## Diagnostics

`bin/doctor` and `bin/doctor --json` inspect setup without approving environment
files, downloading models, or rebuilding an index. They report the hook path,
tools, collections, model locations, last refresh result, and whether recorded
inputs are current, stale, unknown, or unavailable. An unavailable optional
tool is a notice. Broken required setup or an installed but failing tool makes
the command return a failure status with recovery instructions.

Freshness means the recorded input fingerprint matches and the index exists;
it is not an integrity scan of the SQLite database. If QMD reports database
errors despite a current fingerprint, use the foreground refresh and inspect
its log. Manually replacing the database requires a forced refresh.

## File organization

Keep each file focused on one coherent responsibility or feature area. Use
approximately 1,000 lines as a review threshold for hand-written source,
tests, and styles, not a hard cap or automatic CI failure. Generated and
externally maintained files do not need arbitrary splitting.

When extending a large file, consider extracting a cohesive area. Preserve
clear state ownership, readable call paths, and meaningful test boundaries.
Larger files are acceptable when splitting would reduce clarity. Do not
compress formatting, create arbitrary numbered fragments, or move unrelated
responsibilities into a replacement catch-all file to satisfy a line count.

### Markdown pages

Keep each memory, documentation, or other hand-written Markdown page focused
on one topic or reader task. Before extending a long page, review its scope
and remove repetition. Split it when it mixes independent topics, a section
can be read and maintained on its own, or readers must scan unrelated material
to find what they need. Use those signals instead of line, word, or token limits.

Extract complete topics into descriptively named pages. Keep a short overview
and links in the original page, and update indexes and incoming file or heading
links. Keep each rule or decision in one authoritative place. Preserve its
reasons, evidence, dates, status, and enough context to understand it on its own.
Archive obsolete material according to the memory or docs lifecycle rules.

Keep README indexes and automatically loaded instructions concise; link to
detailed guidance instead of copying it. Headings help readers navigate a
coherent page, but do not resolve unrelated topics accumulating in one file.
Larger pages are acceptable when readers need the material together. Do not
compress prose, discard useful context, or create arbitrary numbered fragments
just to make a page shorter. Preserve generated and tool-managed record formats.

## Third-party dependencies

Prefer fewer third-party dependencies. Start with the standard library,
platform APIs, and the smallest complete implementation the project can own
and maintain. Choose that approach when it meets the project's needs with a
reasonable maintenance burden. A dependency is appropriate when its concrete
benefits justify the cost.

Compare both options against the actual requirements. Include validation,
edge cases, security, ongoing maintenance, upgrades, and any additional
packages the dependency brings. Do not compare a complete library with an
incomplete local implementation. Explain the benefit to the project; avoiding
initial implementation work alone is not enough reason to add a package or
framework.

Apply this preference through ordinary technical judgment. It does not add
a separate approval requirement for packages. Preserve existing stack choices
when adopting the foundation; assess dependency changes as part of relevant
project work.

## Test-driven development

Regression fixes and functional changes require automated tests that cover
the changed behavior. Use red-green test-driven development (TDD) whenever
practical:

1. **Red:** Add or update a focused test for the bug or intended behavior.
   Run it before implementation and confirm it fails for the expected reason.
   A setup error or a run that executes no tests does not establish this.
2. **Green:** Make the smallest change that meets the requirement. Run the
   focused test again and confirm it passes.
3. **Refactor:** Improve the code if needed, keep the tests passing, and run
   the relevant checks for affected behavior before delivery.

A test that passes both before and after the change does not demonstrate the
regression or new behavior. If testing first is not practical,
explain why, retain automated coverage for the changed behavior, and report
the verification performed and its limits. Documentation-only edits do not
require new behavior tests; run the applicable document checks.

Exercise the project's external surfaces: user-visible outcomes, public
interfaces, and interactions with external systems. Assert the actual behavior
at these boundaries. Do not call private helpers directly or assert internal
structure, incidental call sequences, or other implementation details. Internal
refactoring that preserves behavior should not require test changes.

Put fakes or mocks at boundaries to the operating system, network, storage,
or other external services. Keep the project's own logic running in the test;
do not replace it with mocks that only prove those mocks were called. Do not
expose private functionality or add production accessors or APIs only for tests.

Use focused test commands during this cycle. The check schedule below governs
broader validation and does not replace the red and green test runs.

### Test cost and coverage

When setup is not the behavior under test, prepare prerequisites through
isolated fixtures or existing public interfaces. Keep real project logic
running through the feature being checked. Retain dedicated end-to-end tests
for the complete setup and user or system journeys; do not add production
interfaces solely to make tests easier.

Use the least costly test level that establishes the required behavior.
Prefer direct application or integration tests for repeated rule checks when
full end-to-end execution adds no distinct evidence. Retain end-to-end coverage
for complete journeys and behavior that depends on the actual interaction
surface. Account for equivalent coverage when moving a case; removing a slow
assertion without replacing its evidence is not an optimization.

Measure representative runs before and after simpler setup or coverage
improvements. Record comparable environments, test inventories, setup costs,
and total validation time so moving work does not hide its cost. Report failed
or retried runs separately from successful-run timings.

Use those results to decide whether parallel execution justifies the added
isolation work. Identify shared mutable data, processes, files, and other
resources; give them clear ownership and independent setup and cleanup.
Validate independence and concurrent execution. Repeated passes alone do not
prove that races are impossible. Keep sequential execution where interference
remains unresolved, and do not hide failures with retries or weaker assertions.

## Checks and project extensions

Choose validation by the changed files and the stage of the work:

| Work | Check |
| --- | --- |
| Discussion, planning, or read-only inspection | No checks. |
| A batch of Markdown edits | `bin/check --documents-only`. |
| Ordinary application code changes | Run relevant application checks locally; require full validation before merge or release as described below. |
| Foundation tooling edits | `bin/check` during development; `--full` when complete. |
| Initial setup; changes to test/build infrastructure, foundation tools, hooks, or CI | `bin/check --full` locally after the edits are complete. |
| Focused checks leave material uncertainty | `bin/check --full` locally. |
| A code PR or release ready for delivery without an enforced full CI gate | `bin/check --full` locally for the final changes. |

Require successful full validation for the code being merged or released.
For ordinary code changes, an enforced CI gate that runs `bin/check --full`
can provide this result without duplicating the full suite locally. A pending,
skipped, or failed CI run does not satisfy the gate. Without such a gate,
including local-only projects, complete full local validation before delivery.
Preserve stronger existing project requirements when adopting this policy.

Batch related edits before checking. A conversational reply is not a release
gate. Reuse a passing result while its relevant source, configuration, and
dependencies are unchanged. Repeat a check when those inputs change or a
failure needs verification. CI always runs the full check. Keep the distinction
between focused local results and a successful full validation result clear in
delivery reports.

`bin/check --documents-only` validates the documented frontmatter subset,
index coverage, local file links, and ordinary heading anchors.
`bin/check` adds Python syntax checks for the tools and tests, shell checks
(Bash for `.envrc`, POSIX shell for the bundled hooks), and Git whitespace
checks. It does not run the disposable-repository tests.

`bin/check --full` adds all copied foundation behavior tests. They use
disposable repositories and simulated QMD/direnv, with no model downloads or
network access. Remote URLs are not fetched by foundation checks.

Keep the foundation checks when adding application tests, builds, and linters.
The default command runs foundation static checks only. Application
typechecking, lint, tests, builds, and package-manager startup belong behind
`--full`. Both routine modes must skip application tools. Run relevant
application commands explicitly during code work. Pass both options through
the integrated entry point, and verify that `--full` runs application checks
only after foundation checks pass. An existing wrapper may incorrectly skip
application checks whenever arguments are set.

Use simulated application commands in adoption tests to prove that routine
modes start none, `--full` starts the required checks, and failures propagate.
Measure routine-mode duration on the target; aim for well under one second
on a small repository. Keep CI assertions about which commands run, without
a fixed timing threshold that depends on machine load.
For generated or externally owned docs, add deliberate patterns to
`checks.exclude` in `.config/knowledge.json`. Avoid broad exclusions that hide
hand-written project knowledge.

If the project uses GitHub, add the optional workflow supplied with the
starter and adapt its branch, runner, dependencies, and check command. Merge
with existing checks where appropriate, and link to the delivered workflow
from these docs. Disposable foundation tests copy `.github/` when present,
`LICENSE.project-starter`, and a project `LICENSE` when present. Include other
required link destinations if project docs refer to them.
Configure CI to run `bin/check --full`. Run it after integration and verify
the CI result for the pushed commit. Other hosts can invoke the same command.

`.project-starter.json` records the copied release and tested QMD version.
Compare future releases manually and merge relevant improvements. These files
belong to the project; there is no automatic updater or runtime dependency on
the starter repository. Retain `LICENSE.project-starter` with copied material.

## Jeeves application validation

Jeeves supports Ruby `>= 3.3, < 4.1`; development uses `.ruby-version`.
The CLI and Rake tasks reject other versions before generation or build work.
Use `bundle install` after selecting a supported Ruby. CI checks Ruby 3.3 and
4.0 on Ubuntu; the local development checkout also runs on macOS. Local checks
do not establish a passing remote CI run.

`bundle exec rake test` runs application tests; a focused invocation is
`bundle exec ruby -Itest test/jeeves/workflow_test.rb`.
`bundle exec rake lint` runs RuboCop's lint checks with explicit application
paths and no mutable cache. `bundle exec rake build` writes only under `gems/`.
`bundle exec rake validate` runs all three. The full foundation entry point
calls this task after foundation checks pass.

Ruby discovery is limited to the maintained `lib/`, `lib/jeeves/`, `test/`, and
`test/jeeves/` files plus the executable, Rakefile, and gemspec. Unrelated nested
worktrees and temporary copies are not traversed. Tests use temporary Git
repositories, home directories, indexes, HTTP ports, and model responses.

The [GitHub workflow](../.github/workflows/check.yml) invokes `bin/check --full`.
Use [GitHub Issues](https://github.com/jubishop/Jeeves/issues) for tracked work.
