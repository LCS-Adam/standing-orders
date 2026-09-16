# tool-name

> One-sentence pitch. What does it do, what problem does it solve.

[![Build](https://img.shields.io/github/actions/workflow/status/USER/REPO/test.yml?branch=main&style=flat-square)](https://github.com/USER/REPO/actions)
[![npm version](https://img.shields.io/npm/v/tool-name?style=flat-square)](https://www.npmjs.com/package/tool-name)
[![Downloads](https://img.shields.io/npm/dm/tool-name?style=flat-square)](https://www.npmjs.com/package/tool-name)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

## Why this exists

[2 to 3 sentences: what manual task this automates, what alternatives exist, what makes this different.]

## Install

```bash
# npm
npm install -g tool-name

# Homebrew
brew install tool-name

# pipx (if Python)
pipx install tool-name

# Cargo (if Rust)
cargo install tool-name
```

## Quick start

```bash
tool-name init my-project
tool-name build
```

Output:

```
✓ Initialized in ./my-project
✓ Built 12 files in 1.2s
```

## Commands

| Command | Description |
|---|---|
| `tool-name init <name>` | Create a new project. |
| `tool-name build` | Build the project. |
| `tool-name deploy` | Deploy to remote. |
| `tool-name help` | Show help. |

<details>
<summary>Full command reference</summary>

### `init`

Initialize a new project.

```bash
tool-name init <name> [--template=<template>]
```

### `build`

[...]

### `deploy`

[...]

</details>

## Global flags

| Flag | Description | Default |
|---|---|---|
| `--config <path>` | Config file path | `./tool.config.yml` |
| `--verbose` | Print debug info | off |
| `--quiet` | Suppress non-error output | off |
| `--no-color` | Disable colored output | off |

## Environment variables

| Variable | Purpose |
|---|---|
| `TOOL_API_KEY` | API key for [service]. |
| `TOOL_LOG_LEVEL` | One of `debug`, `info`, `warn`, `error`. |

## Examples

### Initialize and deploy a new project

```bash
tool-name init my-app --template=react
cd my-app
tool-name deploy --env=production
```

### Run with custom config

```bash
tool-name build --config=./configs/production.yml
```

## Shell completions

```bash
# bash
tool-name completion bash > /etc/bash_completion.d/tool-name

# zsh
tool-name completion zsh > "${fpath[1]}/_tool-name"

# fish
tool-name completion fish > ~/.config/fish/completions/tool-name.fish
```

## Contributing

```bash
git clone https://github.com/USER/REPO
cd REPO
npm install
npm test
```

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE) © 2026 Your Name
