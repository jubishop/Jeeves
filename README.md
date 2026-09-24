# Jeeves

<p align="center">
  <img src="assets/jeeves.png" alt="Jeeves Logo" width="200">
</p>

Jeeves is a command-line tool that creates AI-powered Git commit messages that savagely roasts you and your code.

## Features

- Generate intelligent [conventional commit](https://www.conventionalcommits.org/en/v1.0.0/) messages with [gitmoji](https://gitmoji.dev) based on your staged changes that point out what an idiot you are.
- Option to automatically stage all changes before committing.
- Option to push changes after committing.
- Automatically detects piped input and outputs just the commit message for easy scripting.
- Customizable AI prompts for tailored commit message generation.
- Use cloud models through OpenRouter or local models through Ollama.
- Configure the provider and models once, with optional command-line overrides.

## Example Commit message

✨ refactor(HTMLText): rewrite HTML parsing and rendering from scratch because why not torture future maintainers
Completely scrap the previously sane approach of leveraging NSAttributedString's native HTML importer—because parsing HTML by hand in SwiftUI is obviously a great idea—and replace it with a painfully verbose custom parser that handles only a handful of tags (`<b>`, `<i>`, `<u>`, `<strong>`, `<em>`) by rudimentary string manipulation and manual state tracking.

Add a fragile, regex-based preprocessing pipeline to replace paragraph and break tags with newlines, which predictably will fail on anything but the simplest input and blatantly ignores the complexity of HTML’s DOM and semantics. Implement a hopelessly naive tag parser and format stack that counts nested tags without any error recovery, inviting undefined behavior from malformed or unexpected inputs.

Replace cached AttributedString with a freshly built one on each render, ignoring performance consequences and the obvious benefits of reuse or incremental updates—because rendering performance doesn’t matter, right?

Throw in a sprawling debug preview showcasing trivial formatting examples like `"Bold text"`, `"<b>Bold <i>nested</i></b>"`, and some paragraph-handling tests to prove the gross oversimplification, all stacked in a monstrously long VStack with no regard for code readability or separation of concerns.

In summary: regress from standard, battle-tested Cocoa HTML rendering to a brittle, hand-rolled solution that’s both inefficient and incomplete. Future developers, good luck deciphering this spaghetti; you’ll need it.

## Installation

### Requirements

- Ruby 2.6 or higher
- Git

### Option 1: Install as a Gem (Recommended)

```bash
gem install jeeves-git-commit
```

This automatically adds Jeeves to your PATH.

### Option 2: Build and Install from Source

1. Clone this repository:

```bash
git clone https://github.com/jubishop/Jeeves.git
cd Jeeves
```

2. Build and install the gem:

```bash
gem build jeeves.gemspec
gem install jeeves-git-commit-*.gem
```

### Option 3: Use the Install Script

1. Clone this repository:

```bash
git clone https://github.com/jubishop/Jeeves.git
cd Jeeves
```

2. Run the install script:

```bash
./install.sh
```

The script will:
- Install Jeeves to `/usr/local/bin` (or `~/.local/bin` if you don't have write access)
- Add the install location to your PATH if necessary
- Set up the config directory with the default prompt file
- Make sure the script is executable

### Option 4: Manual Installation

1. Clone this repository:

```bash
git clone https://github.com/jubishop/Jeeves.git
cd Jeeves
```

2. Make the script executable:

```bash
chmod +x bin/jeeves
```

3. Create a symbolic link to make Jeeves available globally:

```bash
ln -s "$(pwd)/bin/jeeves" /usr/local/bin/jeeves
```

## Configuration

### Provider and Model Settings

Jeeves uses OpenRouter unless `GIT_COMMIT_PROVIDER` is set to `ollama`.
Set these environment variables in your shell configuration to make your choice
persistent. Jeeves does not read `.env` files itself; your shell must load them.

| Variable | Purpose | Default |
| --- | --- | --- |
| `GIT_COMMIT_PROVIDER` | `openrouter` or `ollama` | `openrouter` |
| `GIT_COMMIT_MODEL` | OpenRouter model | `x-ai/grok-code-fast-1` |
| `GIT_COMMIT_LOCAL_MODEL` | Ollama model | `qwen3.8:27b` |
| `OLLAMA_HOST` | Ollama server address | `http://127.0.0.1:11434` |
| `GIT_COMMIT_LOCAL_CONTEXT` | Local context window in tokens | `32768` |

The cloud and local model settings are separate. Changing providers preserves
your model choice for each provider. `--provider` and `--model` override the
settings for one command. `--local` is shorthand for `--provider ollama`.

### Local Setup with Ollama

Install [Ollama](https://ollama.com/download), start its server, and download a
model. For example, on an Apple Silicon Mac with 64 GB of memory:

```sh
brew install ollama
brew services start ollama
ollama pull gemma4:26b-nvfp4
```

This package uses Apple's MLX framework and requires Apple Silicon. Gemma 4
26B-A4B uses about 4B parameters per generated token, which helps generation
speed despite its larger total size. `gemma4:12b-mlx` is an alternative with a
smaller download. For other supported hardware, choose a compatible package
from [available models](https://ollama.com/library). Model files, the context
window, and other applications must all fit in memory.

To make local generation the default in fish:

```fish
set -Ux GIT_COMMIT_PROVIDER ollama
set -Ux GIT_COMMIT_LOCAL_MODEL gemma4:26b-nvfp4
```

For bash or zsh, add these lines to your shell startup file:

```sh
export GIT_COMMIT_PROVIDER=ollama
export GIT_COMMIT_LOCAL_MODEL=gemma4:26b-nvfp4
```

Then use Jeeves normally. No API key is needed for Ollama:

```sh
jeeves
jeeves --dry-run
git diff | jeeves

# Use your saved OpenRouter model for one command
jeeves --provider openrouter
```

Local generation disables thinking output and allows up to five minutes for
model loading and generation. The first request can take longer while the model
loads. Increase `GIT_COMMIT_LOCAL_CONTEXT` for larger diffs, within your model's
context and memory limits. Jeeves rejects empty or output-limit-truncated
responses. An Ollama failure does not fall back to OpenRouter.

Ollama listens on localhost by default. For local-only operation, disable its
cloud features using `{"disable_ollama_cloud": true}` in `~/.ollama/server.json`
and restart Ollama. See the [Ollama FAQ](https://docs.ollama.com/faq).

### OpenRouter API Key Setup

The OpenRouter provider requires an API key. Set it as an environment variable:

```bash
export OPENROUTER_API_KEY="your_openrouter_api_key"
```

You can get an API key from [OpenRouter](https://openrouter.ai/).

Optionally, you can specify a different model by setting:

```bash
export GIT_COMMIT_MODEL="openai/gpt-4o"
```

The default model is `x-ai/grok-code-fast-1` if not specified.

### Prompt Configuration

Jeeves supports two levels of prompt configuration with the following priority order:

1. **Repository-Specific Prompt (Highest Priority)**: Create a `.jeeves_prompt` file in the root of your Git repository to customize the prompt for that specific project.
2. **Global Prompt (Fallback)**: Stored in `~/.config/jeeves/prompt`. This is used when no repository-specific prompt is found.

When you run Jeeves, it will:
1. **First** look for a `.jeeves_prompt` file in the root of the current Git repository
2. **If not found**, fall back to the global prompt at `~/.config/jeeves/prompt`

This allows you to have a default prompt for all your projects while still being able to customize the prompt for specific repositories that may have different requirements or coding standards.

**Example Repository-Specific Prompt**: See `example.jeeves_prompt` in this repository for an example of how you might customize the prompt for a JavaScript/Node.js project with specific requirements (that also doesn't roast you).

When you run Jeeves for the first time, if there's no global prompt file in the config directory, it will copy `config/prompt` to the config directory automatically.

The special string: `{{DIFF}}`, in your prompt will be replaced with the current git diff.

## Usage

Navigate to your Git repository and run:

```bash
jeeves [options]
```

Options:

- `-a, --all`: Stage all changes before committing
- `-p, --push`: Push changes after committing
- `-d, --dry-run`: Generate commit message without committing
- `--provider PROVIDER`: Use `openrouter` or `ollama` for this command
- `--local`: Use Ollama for this command
- `--model MODEL`: Override the selected provider's model for this command
- `--version`: Show version information
- `-h, --help`: Show help message

**Note**: When Jeeves detects piped input, it automatically outputs just the commit message without any formatting or logging. This makes it seamless to use in scripts and pipelines.

## Examples

```bash
# Generate a commit message for already staged changes
jeeves

# Stage all changes and generate a commit message
jeeves -a

# Stage all changes, generate a commit message, and push
jeeves -a -p

# Automatically detects piped input and outputs just the message
git diff | jeeves

# Generate a message for specific files
git diff HEAD~1 -- src/*.rb | jeeves

# Use with other git commands
git show HEAD | jeeves

# Store commit message in a variable (bash)
MSG=$(git diff | jeeves)
echo "$MSG"

# Use in a git alias to commit with AI-generated message
git config --global alias.ai-commit '!git diff --staged | jeeves | git commit -F -'
```

## License

MIT

## Development

### Project Structure

Jeeves follows a specific project structure where all gemspec files and built gem files (.gem) are placed in the `gemspec/` folder rather than the root directory. This keeps the root directory clean and organized.

### Rake Tasks

Jeeves provides several rake tasks to streamline development:

```bash
# Run the test suite
rake test

# Build the gem and place it in the gemspec/ folder
rake build

# Build, install and test the gem
rake install

# Build and push the gem to RubyGems
rake push
```

The default task is `rake test`.

### Testing

Jeeves uses Minitest for testing. To run the tests:

```bash
bundle install
rake test
```

The test suite includes:
- Unit tests for the CLI functionality
- Tests for version consistency
- Mock tests for API interactions (using WebMock)

## Author

[Justin Bishop (jubishop)](https://github.com/jubishop)
