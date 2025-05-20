#!/usr/bin/env bash
set -e

# Determine install location
INSTALL_DIR="/usr/local/bin"
if [[ ! -d "$INSTALL_DIR" || ! -w "$INSTALL_DIR" ]]; then
  # Fall back to user's bin directory if /usr/local/bin is not writable
  INSTALL_DIR="$HOME/.local/bin"
  mkdir -p "$INSTALL_DIR"
  
  # Check if ~/.local/bin is in PATH
  if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo "Adding $INSTALL_DIR to your PATH"
    
    # Determine shell
    SHELL_NAME=$(basename "$SHELL")
    
    # Add to the appropriate shell config file
    if [ "$SHELL_NAME" = "fish" ]; then
      # For fish shell
      FISH_CONFIG="$HOME/.config/fish/config.fish"
      mkdir -p "$(dirname "$FISH_CONFIG")"
      echo "set -gx PATH \$PATH $INSTALL_DIR" >> "$FISH_CONFIG"
      echo "Added PATH to $FISH_CONFIG. Restart your shell or run 'source $FISH_CONFIG'"
    elif [ "$SHELL_NAME" = "zsh" ]; then
      # For zsh
      echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$HOME/.zshrc"
      echo "Added PATH to ~/.zshrc. Restart your shell or run 'source ~/.zshrc'"
    else
      # Default to bash
      echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$HOME/.bashrc"
      echo "Added PATH to ~/.bashrc. Restart your shell or run 'source ~/.bashrc'"
    fi
  fi
fi

# Install the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/bin/jeeves"

if [ ! -f "$SCRIPT_PATH" ]; then
  # Check if we're installing from a version without bin directory
  if [ -f "$SCRIPT_DIR/jeeves" ]; then
    SCRIPT_PATH="$SCRIPT_DIR/jeeves"
  else
    echo "Error: Could not find jeeves script in $SCRIPT_DIR/bin or $SCRIPT_DIR"
    exit 1
  fi
fi

# Make it executable
chmod +x "$SCRIPT_PATH"

# Create symbolic link
LINK_PATH="$INSTALL_DIR/jeeves"
ln -sf "$SCRIPT_PATH" "$LINK_PATH"

# Create config directory and copy prompt file if needed
CONFIG_DIR="$HOME/.config/jeeves"
mkdir -p "$CONFIG_DIR"
PROMPT_FILE="$CONFIG_DIR/prompt"

if [ ! -f "$PROMPT_FILE" ]; then
  if [ -f "$SCRIPT_DIR/config/prompt" ]; then
    cp "$SCRIPT_DIR/config/prompt" "$PROMPT_FILE"
    echo "Copied default prompt file to $PROMPT_FILE"
  else
    echo "Warning: Could not find prompt file template"
  fi
fi

echo "Jeeves has been installed to $LINK_PATH"
echo "You can run it by typing 'jeeves' in your terminal"
