---
title: Spec Agent Kibo – Installation
version: 1.0
lastUpdated: 2025-08-14
---

Install and verify Spec Agent Kibo locally so you can run the create-spec and execute-tasks flows.

Overview
--------

Spec Agent Kibo is instruction-driven and editor-agnostic. You primarily need:

- The instructions folder in your home directory
- Project standards in your repo
- (Optional) Atlassian MCP configured in your editor

Requirements
------------

- OS: Windows, macOS, or Linux
- Git installed
- An AI-enabled editor (e.g., Claude Code, Cursor)
- Optional: Atlassian MCP configured in your editor if you want Jira-driven specs

Tool prerequisites
------------------

Some helper scripts and flows require jq to be available in your PATH.

- Check if jq is installed

```bash
jq --version
```

- macOS (Homebrew)

```bash
brew install jq
```

- Debian/Ubuntu

```bash
sudo apt-get update
sudo apt-get install -y jq
```

- Fedora/RHEL/CentOS (dnf or yum)

```bash
sudo dnf install -y jq
# or
sudo yum install -y jq
```

- Arch/Manjaro

```bash
sudo pacman -S jq
```

- Alpine

```bash
sudo apk add --no-cache jq
```

- Windows (Git Bash) — no admin required

```bash
mkdir -p "$HOME/.local/bin"
curl -L -o "$HOME/.local/bin/jq.exe" https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-windows-amd64.exe
chmod +x "$HOME/.local/bin/jq.exe"
if ! grep -q 'PATH="$HOME/.local/bin' "$HOME/.bashrc" 2>/dev/null; then echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"; fi
exec "$SHELL" -l
jq --version
```

Optional (Windows with MSYS2):

```bash
pacman -S --noconfirm mingw-w64-x86_64-jq
```

Recommended install (from local clone)
--------------------------------------

1. Clone the repository

```bash
git clone https://github.com/waynehearn/agent-os.git
cd agent-os
```

1. Run the local setup script

- macOS/Linux (Terminal)

```bash
bash ./setup.sh
```

- Windows (Git Bash)

```bash
./setup.sh
```

1. (Optional) Install editor integrations from the local clone

- Claude Code

```bash
bash ./setup-claude-code.sh
```

- Cursor (run inside a project repo to add .cursor rules)

```bash
bash ./setup-cursor.sh
```

Manual alternative — copy or symlink
------------------------------------

If you prefer not to run the script, place the instructions in your home `~/.agent-os/instructions/` path.

Option A: Copy instructions (simple)

```bash
# macOS/Linux/Windows (Git Bash)
mkdir -p "$HOME/.agent-os/instructions"
cp -R ./instructions/* "$HOME/.agent-os/instructions/"
```

Option B: Symlink (advanced; keeps a single source of truth)

```bash
# macOS/Linux/Windows (Git Bash)
mkdir -p "$HOME/.agent-os"
ln -sfn /path/to/your/repo/.agent-os/instructions "$HOME/.agent-os/instructions"
```

Step 2 — Add project standards
------------------------------

Ensure project standards live inside your repository at:

- `@.agent-os/standards/` (style, tech stack, best practices)

If you need to bootstrap:

```bash
# macOS/Linux/Windows (Git Bash)
mkdir -p .agent-os/standards
```

Step 3 — (Optional) Configure Atlassian MCP
--------------------------------------

To enable Jira-driven specs, configure a Atlassian MCP in your editor:

- Add your Atlassian MCP extension/integration
- Authenticate (OAuth or API token)
- Confirm you can read a test issue

References:

- Configuration guide: [configuration.md](./configuration.md)

Step 4 — Verify installation
----------------------------

Run a quick smoke test to confirm paths and validators work:

- Open [smoke-tests.md](./smoke-tests.md)
- Run Test 1 (Jira example), then verify the created spec folder and files

Uninstall / cleanup
-------------------

- Remove `~/.agent-os/instructions/` or the symlink if you used one
- Remove `@.agent-os/specs/` folders if you want to clear generated specs

Next steps
----------

- Quickstart: [quickstart.md](./quickstart.md)
- Create Spec Usage: [create-spec-usage.md](./create-spec-usage.md)
- Configuration: [configuration.md](./configuration.md)
- Troubleshooting: [troubleshooting.md](./troubleshooting.md)

Verify installation
-------------------

Run from the repo root:

```bash
bash ./tools/verify-install.sh
# Optional checks
bash ./tools/verify-install.sh --check-claude
bash ./tools/verify-install.sh --check-cursor   # run inside a project with .cursor
./tools/verify-jq.sh                             # confirm jq is on PATH
```
