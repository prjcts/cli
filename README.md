# 📦 dev CLI

The `dev` command is a fast, fuzzy finder for jumping into your projects with your favorite editor. It opens Neovim, VS Code, or any other tool — from anywhere — in one keypress.

## 🚀 Features

- 🧠 Remembers your project directories
- 🔍 Fuzzy finds folders with `.git`, `package.json`, or custom triggers
- 🪄 Opens with your favorite editor (`nvim`, `code`, etc.)
- 🖥️ Works across shells (Zsh, Bash, Fish)
- 🧩 Optional tab completion
- 🧼 CLI subcommands for managing triggers and projects

## 🛠️ Installation

```bash
curl -fsSL https://raw.githubusercontent.com/prjcts/cli/v0.1.3/install.sh | bash
```

Supports Zsh, Bash, Fish, and POSIX shells.

## 💡 Usage

```bash
dev                # Fuzzy find project folders and open with configured editor
dev add            # Add a parent directory to search for projects
dev add -t         # Add a custom trigger (e.g., .pyproject.toml)
dev clean          # Remove saved project directories
dev clean -t       # Remove triggers
dev set -c         # Set your launch command (nvim, code, emacs...)
dev show command   # Display the current launch command
dev help           # Show help
```

## 🧠 Example

```bash
dev set -c
# Enter: nvim

dev add
# Enter: ~/Development

dev
# Select: ~/Development/my-project
# => Launches: nvim ~/Development/my-project
```

## ✅ Supported Triggers

Out of the box:

- `.git`
- `package.json`

You can add your own via `dev add -t`.

## 🧩 Shell Completion

- Zsh and Fish completions are automatically installed
- Bash support coming soon

## 🧪 Version

```bash
dev --version
```

## 🛠 Contributing

PRs welcome! Feel free to fork or file issues.

## 📄 License

MIT — © 2024 [@prjcts](https://github.com/prjcts)
