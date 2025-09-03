# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Jeeves is a Ruby gem that generates AI-powered Git commit messages using OpenRouter API. It's a CLI tool that analyzes staged git changes and creates conventional commit messages with gitmoji that "mercilessly roast" the code author.

## Essential Commands

### Testing
```bash
# Run all tests
rake test

# Run tests (default rake task)
rake
```

### Building and Installation
```bash
# Build gem and place in gems/ folder
rake build

# Build, install and test the gem
rake install

# Build and push to RubyGems
rake push
```

### Code Quality
```bash
# Run RuboCop linter
bundle exec rubocop
```

### Development Setup
```bash
# Install dependencies
bundle install

# Make the binary executable (for manual installation)
chmod +x bin/jeeves
```

## Architecture

### Core Components

- **CLI Entry Point**: `bin/jeeves` - executable script that requires and runs `lib/jeeves.rb`
- **Main Module**: `lib/jeeves.rb` - contains the `CLI` class with all core functionality
- **Version**: `lib/jeeves/version.rb` - single constant defining gem version

### Key Architectural Patterns

**Single-Class Design**: Unlike typical Ruby gems, Jeeves uses a single `CLI` class in `lib/jeeves.rb` that handles:
- Command-line option parsing
- Git operations (staging, diff, commit)
- OpenRouter API integration
- Prompt file management (global vs repository-specific)

**Prompt System**: Two-tiered configuration:
1. Repository-specific: `.jeeves_prompt` in git root (highest priority)
2. Global fallback: `~/.config/jeeves/prompt`

**API Integration**: Uses OpenRouter API with configurable models via environment variables:
- `OPENROUTER_API_KEY` (required)
- `GIT_COMMIT_MODEL` (defaults to `x-ai/grok-code-fast-1`)

### Testing Framework

Uses Minitest with extensive mocking:
- **WebMock**: Stubs HTTP requests to OpenRouter API
- **Mocha**: Stubs system calls and git operations
- **Isolated Testing**: Creates temporary directories to avoid affecting real config files
- **Test Helper**: `test/test_helper.rb` provides comprehensive test environment setup

## Development Workflow

### File Structure Conventions
- Built gems are placed in `gems/` directory (not root)
- Config files go in `config/` directory
- Prompt template is in `config/prompt`

### Environment Variables Required
- `OPENROUTER_API_KEY`: Required for API access
- `GIT_COMMIT_MODEL`: Optional model override (defaults to `x-ai/grok-code-fast-1`)

### Key Constants and Paths
- `CONFIG_DIR`: `~/.config/jeeves`
- `PROMPT_FILE`: `~/.config/jeeves/prompt`
- Temp files use `Dir.tmpdir` for commit messages

## Dependencies
- **Runtime**: `json` gem for API communication
- **Development**: `rake`, `minitest`, `webmock`, `mocha`, `rubocop`
- **Ruby Version**: >= 2.6.0