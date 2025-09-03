# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

Jeeves is a Ruby gem (≥2.6.0) that generates AI-powered Git commit messages with attitude. It's a CLI tool that uses OpenRouter API to create conventional commit messages with gitmoji that "mercilessly roast" the code author based on staged git changes.

## Essential Commands

### Setup
```bash
bundle install                    # Install dependencies
chmod +x bin/jeeves              # Make binary executable (for local dev)
```

### Testing
```bash
rake test                        # Run all tests (default rake task)
rake                             # Same as rake test
ruby -Ilib:test test/jeeves/cli_test.rb  # Run single test file
```

### Code Quality
```bash
bundle exec rubocop              # Run RuboCop linter
bundle exec rubocop -A           # Auto-fix safe violations
```

### Build & Release
```bash
rake build                       # Build gem → gems/jeeves-git-commit-VERSION.gem
rake install                     # Build, install, and test locally
rake push                        # Build and push to RubyGems (requires gem signin)
```

## Architecture

### Single-Class Design
Unlike typical Ruby gems, Jeeves uses a monolithic approach:

- **Entry Point**: `bin/jeeves` → requires `lib/jeeves.rb` → runs `Jeeves::CLI.new.run`
- **Core Logic**: `Jeeves::CLI` class in `lib/jeeves.rb` handles everything:
  - Option parsing (OptionParser)
  - Git operations (`git diff --staged`, `git commit`, `git push`)
  - OpenRouter API integration (Net::HTTP)
  - Two-tier prompt system (repo-specific vs global)
- **Version**: `lib/jeeves/version.rb` contains single `VERSION` constant

### Data Flow
1. Parse CLI options (`-a` for auto-stage, `-p` for auto-push)
2. Optionally stage changes with `git add -A`
3. Get staged diff with `git diff --staged`
4. Load prompt file (`.jeeves_prompt` in git root OR `~/.config/jeeves/prompt`)
5. Replace `{{DIFF}}` placeholder in prompt with actual diff
6. POST to OpenRouter API with prompt
7. Write response to temp file and commit with `git commit -F`
8. Optionally push changes

### Configuration System
Two-tier prompt configuration (checked in order):
1. Repository-specific: `.jeeves_prompt` in git root (highest priority)  
2. Global fallback: `~/.config/jeeves/prompt` (copied from `config/prompt` on first run)

## Environment Variables

- **`OPENROUTER_API_KEY`** (required): OpenRouter API key for AI model access
- **`GIT_COMMIT_MODEL`** (optional): Model override (default: `openai/gpt-4o-mini`)

Used in `lib/jeeves.rb:generate_commit_message()` for API requests.

## Development Workflows

### Testing Isolation
Tests use extensive mocking and temporary directories:
- **WebMock**: Stubs OpenRouter API calls
- **Mocha**: Stubs git system calls (`system()`, backticks)
- **Isolated Config**: Each test gets its own `~/.config/jeeves` equivalent

### Quick Iteration
```bash
# Edit code, run specific test
ruby -Ilib:test test/jeeves/cli_test.rb

# Test locally without installing
./bin/jeeves -h

# Load in console (no bin/console provided)
ruby -Ilib -r jeeves -e 'Jeeves::CLI.new'
```

## Testing Notes

**Framework**: Minitest with comprehensive mocking
**Coverage**: No coverage tools configured
**Focus on specific tests**: Use Ruby's `-n` flag or method name patterns

**Critical Rule**: Do not use `sleep()` in tests. This codebase follows good practices and contains no sleep calls. For future tests requiring timing:
- Stub `Time.now` for deterministic time-based logic
- Use condition polling with bounded timeouts instead of arbitrary waits
- Mock external dependencies that might introduce delays
- Leverage WebMock/Mocha for deterministic API responses

## Release Process

1. **Version Bump**: Edit `lib/jeeves/version.rb` → update `VERSION` constant
2. **Build**: `rake build` → creates `gems/jeeves-git-commit-VERSION.gem`
3. **Test Install**: `rake install` (builds + installs locally)
4. **Publish**: `rake push` (requires `gem signin` for RubyGems.org access)

**Preflight Checklist**:
```bash
rake test           # All tests pass
bundle exec rubocop # No style violations
rake build          # Gem builds successfully
```

## File Structure Conventions

- **Gem Files**: Built gems go in `gems/` directory (not root)
- **Config Template**: Default prompt is in `config/prompt`
- **Executable**: `bin/jeeves` (not `exe/`)
- **Dependencies**: Minimal runtime deps (`json` gem only)

## Configuration Files

- **`config/prompt`**: Default roasting prompt template with `{{DIFF}}` placeholder
- **`example.jeeves_prompt`**: Example repo-specific prompt (JavaScript-focused, less roasty)
- No CI workflows (`.github/` absent)
- No RuboCop config (uses defaults)

## Integration Points

### Git Integration
- Requires staged changes (`git diff --staged`)
- Creates temporary commit message files in `Dir.tmpdir`
- Executes git commands via `system()` calls

### OpenRouter API
- Fixed endpoint: `https://openrouter.ai/api/v1/chat/completions`
- Supports reasoning models (GPT-5, o1) with system message formatting
- Request timeout handling and structured error responses

## Troubleshooting

If encountered during development - no common issues found in current reconnaissance.

## See Also

- **End-user setup and usage**: See [README.md](README.md)
- **Project history and examples**: See [README.md](README.md) Development section
- **Claude-specific context**: See [CLAUDE.md](CLAUDE.md)
