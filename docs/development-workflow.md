---
status: current
---

# Development workflow

This page records this project's own commands and integrations. Shared rules
are in the [foundation pages](foundation/README.md).

## Setup

```sh
bin/setup
bin/doctor
bin/check --full
```

Setup needs Git and Python 3.9 or later, and checks also need ShellCheck.
QMD and direnv are optional; setup reports skipped features. Install td and
run `td init` as described in [task tracking](foundation/task-tracking.md).
Create `.envrc` only when the project needs environment settings, and review
it before running `direnv allow`; search does not need it.

## Checks

Follow the [check schedule](foundation/engineering-policy.md#checks).
`bin/check-application` runs `bundle exec rake validate` from the repository
root: the application tests, RuboCop lint checks, and the gem build. See
[application validation](#jeeves-application-validation) for each task.

## Runtime and toolchain versions

Jeeves supports Ruby 3.3 or newer, declared in `jeeves.gemspec` and enforced
by `lib/jeeves/runtime.rb`. CI checks the 3.3 minimum and the latest stable
Ruby on every run. The repository has no `.ruby-version`: rbenv cannot name
the latest stable release, and local development uses Homebrew's current
Ruby. See
[application validation](#jeeves-application-validation) and the
[version policy](foundation/engineering-policy.md#runtime-and-toolchain-versions).

Declare only the minimum Ruby in `jeeves.gemspec`; do not add an upper bound.
A launcher with a bound stops at startup once Homebrew's Ruby moves past it,
and users must wait for a new gem release. Version 3.1.0 had a `< 4.1` bound
and rejected Ruby 4.1; version 3.1.1 removed it.

## Deployment

Pushes do not deploy or release. Publishing the gem with
`bundle exec rake push` is an explicit release action, never part of normal
validation. Nonfunctional changes, including docs, task tracking, and
comments, may be pushed without a version bump or gem release. Follow the
[deployment policy](foundation/engineering-policy.md#deployment-decisions).

## Jeeves application validation

Jeeves supports Ruby 3.3 or newer; development uses Homebrew's current Ruby.
The CLI and Rake tasks reject older versions before generation or build work.
Use `bundle install` after selecting a supported Ruby. CI checks Ruby 3.3 and
the latest stable Ruby on Ubuntu; the local development checkout also runs on
macOS. Local checks do not establish a passing remote CI run.

`bundle exec rake test` runs application tests; a focused invocation is
`bundle exec ruby -Itest test/jeeves/workflow_test.rb`.
`bundle exec rake lint` runs RuboCop's lint checks with explicit application
paths and no mutable cache. `bundle exec rake build` writes only under `gems/`.
`bundle exec rake validate` runs all three. `bin/check-application` runs this
task, and `bin/check --full` calls it after the foundation checks pass.

Ruby discovery is limited to the maintained `lib/`, `lib/jeeves/`, `test/`, and
`test/jeeves/` files plus the executable, Rakefile, and gemspec. Unrelated nested
worktrees and temporary copies are not traversed. Tests use temporary Git
repositories, home directories, indexes, HTTP ports, and model responses.

The [GitHub workflow](../.github/workflows/check.yml) invokes `bin/check --full`.
Use [GitHub Issues](https://github.com/jubishop/Jeeves/issues) for tracked work.

## Project Starter

`.project-starter.json` records the installed Project Starter release and the
hashes of its managed files. Update them with Project Starter's `bin/sync`,
and record any intentional local change as an override with its reason.
