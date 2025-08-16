# Quickstart Demo

This folder is a minimal, ready-to-run HTML/JS example to test Spec Agent K with Claude Code.

What you’ll do

- Install the instructions to your home folder (one-time)
- Open this folder in Claude Code
- Run the prefilled create-spec request from `initial-request.md`
- See the generated spec and tasks under `.agent-os/specs/`

Prerequisites

- Claude Code (or compatible AI editor)
- Windows PowerShell available (your shell is pwsh)

One-time setup: install instructions

If you haven’t installed the instruction set to `~/.agent-os/instructions/`, do this once:

PowerShell (copy/paste into a pwsh terminal at the repo root):

```powershell
# From the repo root
$homeDir = [Environment]::GetFolderPath('UserProfile')
$target = Join-Path $homeDir '.agent-os/instructions'
$newItemParams = @{ ItemType = 'Directory'; Force = $true }
New-Item -Path $target -ErrorAction SilentlyContinue @newItemParams | Out-Null
Copy-Item -Recurse -Force -Path (Join-Path $PWD 'instructions/*') -Destination $target
Write-Host "Installed instructions to $target"
```

Note: You can also use the provided setup scripts in the repo root (e.g., `setup-claude-code.sh`) if you prefer Git Bash.

Run the demo (create-spec)

1) Open this folder (`examples/quickstart`) in Claude Code.
2) Open `initial-request.md`.
3) Send the entire file to Claude Code (as a message or “Run with Claude”) to execute.

What happens

- The flow reads local standards from `@.agent-os/standards/` (this folder ships with minimal examples).
- It creates a spec folder at `.agent-os/specs/YYYY-MM-DD-add-kibo-agent-badge-widget/` with:
  - `spec.md`, `spec-lite.md`
  - `sub-specs/technical-spec.md` (+ conditional DB/API files)
  - `tasks.md`
  - `context/` lite-first artifacts

Open the demo site

- Open `examples/quickstart/site/index.html` in your browser to view the page. After tasks are implemented, refresh to see the Spec Agent K badge.

Run the demo (execute-tasks)

After the spec is created:

1) Open `examples/quickstart/execute-tasks.md`.
2) Replace `YYYY-MM-DD` in `spec_folder_path` with today’s date used in your generated spec folder name.
3) Send the entire file to Claude Code to execute. By default it runs the next uncompleted parent task. To target a specific task, uncomment `specific_tasks` and set numbers after checking `[spec_folder_path]/tasks.md`.

After creation

- Open the new spec folder and review `tasks.md`.
- Optionally, run targeted tasks using the execute flow (see `docs/create-spec-usage.md`).

Troubleshooting

- If you see “instructions not found,” ensure you ran the one-time setup above so `~/.agent-os/instructions/` exists.
- If create-spec asks about overwriting files, the request sets `overwrite_existing: true` to keep this demo simple.
- Lite context artifacts are intentionally minimal in this demo.

Credits

- This demo uses the project’s instruction set and minimal standards for a clean first run.
