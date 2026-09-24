---
status: current
---

# Release notes

## 3.0.0

Jeeves supports local Ollama models alongside OpenRouter. Save the provider
and each provider's model independently. Plain `jeeves` uses those settings;
flags override them for one invocation. OpenRouter remains the package default.

The bundled prompt still includes a sarcastic roast, with clearer accuracy
and length instructions. Existing personal prompts are never overwritten.

Git failures now stop the workflow. `--all --dry-run` previews changes in a
temporary index, including untracked files, without modifying the real index.
Jeeves checks for changes to staged content or HEAD during generation before
committing. Commit message files use unique temporary paths and are cleaned up.

### Upgrade requirements

- Ruby 3.3 through 4.0 is required. Reinstall the gem after selecting a supported
  Ruby so the launcher uses that runtime.
- Generated subjects must use conventional commit syntax by default. Jeeves
  normalizes the emoji and inserts a blank line before the body. Use
  `GIT_COMMIT_MESSAGE_FORMAT=plain` for intentionally different formats.
- Empty output, leaked reasoning, malformed responses, and output-limit
  truncation return an error instead of creating a commit.
- Large inputs have configurable byte and local context limits. See
  [configuration](configuration.md) for settings and failure timeouts.

Development now uses Project Starter for setup, knowledge search, Git hooks,
isolated worktrees, and validation. Application code has separate components
for Git, prompts, providers, settings, and message checks. Tests exercise the
CLI and real Git repositories with HTTP fixtures at the network boundary.
