# Jeeves

<p align="center">
  <img src="assets/jeeves.png" alt="Jeeves Logo" width="200">
</p>

Jeeves is a command-line tool that helps you create AI-powered Git commit messages. It streamlines your Git workflow by automatically generating meaningful commit messages based on your code changes.

## Features

- Generate intelligent [conventional commit](https://www.conventionalcommits.org/en/v1.0.0/) messages with [gitmoji](https://gitmoji.dev) based on your staged changes.
- Option to automatically stage all changes before committing
- Option to push changes after committing
- Customizable AI prompts for tailored commit message generation
- Choose any AI model (chat-gpt 4.1-mini by default)

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

### API Key Setup

Jeeves requires an OpenRouter API key to generate commit messages. You need to set this as an environment variable:

```bash
export OPENROUTER_API_KEY="your_openrouter_api_key"
```

You can get an API key from [OpenRouter](https://openrouter.ai/).

Optionally, you can specify a different model by setting:

```bash
export GIT_COMMIT_MODEL="openai/gpt-4o"
```

The default model is `openai/gpt-4.1-mini` if not specified.

### Prompt Configuration

Jeeves supports two levels of prompt configuration with the following priority order:

1. **Repository-Specific Prompt (Highest Priority)**: Create a `.jeeves_prompt` file in the root of your Git repository to customize the prompt for that specific project.
2. **Global Prompt (Fallback)**: Stored in `~/.config/jeeves/prompt`. This is used when no repository-specific prompt is found.

When you run Jeeves, it will:
1. **First** look for a `.jeeves_prompt` file in the root of the current Git repository
2. **If not found**, fall back to the global prompt at `~/.config/jeeves/prompt`

This allows you to have a default prompt for all your projects while still being able to customize the prompt for specific repositories that may have different requirements or coding standards.

**Example Repository-Specific Prompt**: See `example.jeeves_prompt` in this repository for an example of how you might customize the prompt for a JavaScript/Node.js project with specific requirements.

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
- `--version`: Show version information
- `-h, --help`: Show help message

## Examples

```bash
# Generate a commit message for already staged changes
jeeves

# Stage all changes and generate a commit message
jeeves -a

# Stage all changes, generate a commit message, and push
jeeves -a -p
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
