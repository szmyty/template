# 🛠️ Your Project Name

A modern Python CLI tool for [insert your project's purpose here] — built with [Click](https://click.palletsprojects.com/) and powered by version-controlled dev environments using [ASDF](https://asdf-vm.com/) and [Taskfile.dev](https://taskfile.dev/).

---

## 🚀 Quickstart

### 1. Set up your development environment

Before using this CLI, you’ll need to install all required tool versions locally using ASDF.

**snippet**
source ./scripts/install-devtools.sh --local
**endsnippet**

This will:
- Install ASDF and the required plugins
- Automatically detect and install all tool versions from any `.tool-versions` files in the project
- Set up [Taskfile](https://taskfile.dev/) for task automation (if needed)

> **Tip:** You can also add this to your shell profile (`~/.bashrc`, `~/.zshrc`) if you want to activate it automatically.

---

### 2. Run the CLI tool

Once the environment is set up, you can use the CLI:

**snippet**
# Replace this with your actual CLI entry point
your-cli-tool --help
**endsnippet**

---

## 📖 CLI Reference

To show full help output with all commands and options, run:

**snippet**
your-cli-tool --help
**endsnippet**

If you'd like to include the output in this README, you can generate it with:

**snippet**
your-cli-tool --help > docs/cli-help.txt
**endsnippet**

And then add to your README like this:

<details>
<summary>📜 CLI Help Output</summary>

**snippet**
# (Paste the contents of cli-help.txt here)
**endsnippet**

</details>

---

## 🧪 Local Development Notes

If you're developing or debugging the CLI:

**snippet**
# Use taskfile if you set it up
task dev

# Or run the Python script directly
python -m your_cli_package_name --help
**endsnippet**

---

## 🧰 Requirements

- Python 3.10+ (managed via ASDF)
- ASDF version manager
- `click` (installed via poetry or requirements.txt)
- Any other dependencies you define

---

## 🧼 Uninstall / Clean Slate

**snippet**
rm -rf .cache/
rm -rf .venv/
**endsnippet**

---

## 🤝 Contributing

PRs welcome! Please run `source ./scripts/install-devtools.sh --local` before making changes to ensure consistent tooling.

---

## 📄 License

[MIT](LICENSE)
