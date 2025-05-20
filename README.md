# Jeeves

Jeeves is a command-line tool that helps you create AI-powered Git commit messages. It streamlines your Git workflow by automatically generating meaningful commit messages based on your code changes.

## Features

- Generate intelligent commit messages based on your staged changes
- Option to automatically stage all changes before committing
- Option to push changes after committing
- Customizable AI prompts for tailored commit message generation

## Installation

### Requirements

- Ruby 2.6 or higher
- Git

### Steps

1. Clone this repository:

```bash
git clone https://github.com/jubishop/Jeeves.git
cd Jeeves
```

2. Make the script executable:

```bash
chmod +x jeeves
```

3. Create a symbolic link to make Jeeves available globally (optional):

```bash
ln -s "$(pwd)/jeeves" /usr/local/bin/jeeves
```

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

## Configuration

Jeeves stores its configuration in `~/.config/jeeves/`. You can customize the AI prompt by editing the `prompt` file in this directory.

When you run Jeeves for the first time, if there's no prompt file in the config directory, it will check for a bundled prompt file in the same directory as the script and copy it to the config directory automatically.

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

## Author

[Justin Bishop (jubishop)](https://github.com/jubishop)
