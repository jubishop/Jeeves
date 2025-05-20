# Jeeves

<p align="center">
  <img src="img/jeeves.png" alt="Jeeves Logo" width="300"/>
</p>

## AI-Powered Git Commit Messages

**Jeeves** is your intelligent assistant for generating high-quality, context-aware Git commit messages using generative AI. With a single command, Jeeves analyzes your staged changes and crafts a clear, descriptive commit message—saving you time and improving your project's commit history.

---

### ✨ Features
- **AI-Generated Commit Messages:** Uses OpenRouter AI models (default: GPT-4.1-mini) to summarize your staged changes.
- **Customizable Prompts:** Personalize the commit message style via a prompt file.
- **Easy Integration:** Simple CLI with options to stage all changes and push after commit.
- **Secure:** API key is read from your environment, never stored in code.

---

## 🚀 Quick Start

1. **Install Requirements:**
   - Ruby (>= 2.5)
   - Git

2. **Set Up API Key:**
   - Get an API key from [OpenRouter](https://openrouter.ai/).
   - Export it in your shell:
     ```sh
     export OPENROUTER_API_KEY=your_api_key_here
     ```

3. **Create a Prompt File:**
   - Place your custom prompt in `~/.config/jeeves/prompt`.
   - Example prompt:
     ```
     Write a concise, clear Git commit message describing the following changes:
     {{DIFF}}
     ```

4. **Usage:**
   - Stage your changes as usual, or let Jeeves do it for you:
     ```sh
     jeeves -a   # Stages all changes and generates a commit message
     jeeves      # Uses currently staged changes
     jeeves -p   # Pushes after committing
     jeeves -a -p  # Stage all, commit, and push
     ```

---

## ⚙️ Options

- `-a`, `--all`   : Stage all changes before committing
- `-p`, `--push`  : Push changes after committing
- `-h`, `--help`  : Show help message

---

## 📝 Example

```sh
$ jeeves -a
Generated commit message:
------------------------
Add user authentication and update login UI
------------------------
```

---

## 🛠️ Configuration
- **Prompt File:** `~/.config/jeeves/prompt` (required)
- **API Key:** Set `OPENROUTER_API_KEY` in your environment
- **Model:** Optionally set `GIT_COMMIT_MODEL` (default: `openai/gpt-4.1-mini`)

---

## 📄 License
MIT

---

<p align="center">
  <em>Let Jeeves handle your commit messages—so you can focus on building.</em>
</p>
