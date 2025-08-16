---
title: Spec Agent K – Quickstart
version: 1.0
lastUpdated: 2025-08-14
---

Start here if you’re new. In ~10 minutes you’ll create a spec from a simple example, verify outputs, and run targeted tasks.

What is Spec Agent K?
------------------

Spec Agent K is a system for spec‑driven agentic development. It gives AI coding agents structured workflows aligned to your standards, stack, and codebase context so they ship quality code on the first try—not the fifth.

Works with
----------

- Claude Code, Cursor, or other AI coding tools
- New products or established codebases
- Big features or small fixes
- Any language or framework

Prerequisites
-------------

- Spec Agent K instructions at `@~/.agent-os/instructions/`
- For helper scripts (discovery, hashing): Bash + `jq` on PATH (see `docs/installation.md`)

Local demo (ready-to-run)
-------------------------

For a minimal, preconfigured example, open `examples/quickstart/` in Claude Code and run `initial-request.md` to execute the create-spec flow. This folder includes local project standards under `@.agent-os/standards/` so it works out of the box after you install the instructions.

Step 1 — Run the demo request
-----------------------------

Claude Code command:

```text
/create-spec @examples/quickstart/initial-request.md
```

The request generates a spec for a simple HTML/CSS/JS badge widget and writes outputs under `.agent-os/specs/YYYY-MM-DD-add-kibo-agent-badge-widget/`.

Step 2 — Verify outputs
-----------------------

- Folder exists: `@.agent-os/specs/YYYY-MM-DD-add-kibo-agent-badge-widget/`
- Files exist:
  - `spec.md`
  - `spec-lite.md`
  - `sub-specs/technical-spec.md`
  - `sub-specs/database-schema.md` (only when DB required)
  - `sub-specs/api-spec.md` (only when API required)
  - `tasks.md`
  - `context/` (lite-first artifacts)
    - `facts.md` (may say “Mission (lite): N/A” — that’s OK)
    - `manifest.json` (hashes/mtime for skip-by-hash)
    - `meta.json` (counts/flags for fast checks)
- `spec.md` core sections in strict order: Overview, User Stories, Scope, Deliverables, Technical Details; optional sections appended when applicable: API Specification, Database Changes

Tip: See the Glossary for the roles of `spec.md` vs `spec-lite.md`.
Tip: See the Glossary for lite-first artifacts (`facts.md`, `manifest.json`, `meta.json`).

Step 3 — Run the demo tasks
---------------------------

Claude Code command (after you verify outputs):

```text
/execute-tasks @.agent-os/specs/YYYY-MM-DD-add-kibo-agent-badge-widget/tasks.md
```

By default this runs the next uncompleted parent task. To target specific tasks, open `[spec_folder_path]/tasks.md` first, note the parent task numbers, and add a `specific_tasks` list.

Note on API/DB sub-specs during execution:

- The executor uses a hybrid rule to consult `sub-specs/api-spec.md` and `sub-specs/database-schema.md` when either the spec flags API/DB changes (in `meta.json`) or the current task text clearly indicates API/DB work. Reads are selective and manifest-aware to keep context lean.

Expected summary output
-----------------------

After execution, a compact summary is written to `[spec_folder_path]/context/tasks-summary.json`.

Example (truncated):

```json
{
  "run": {
  "specFolderPath": "@.agent-os/specs/2025-08-14-add-kibo-agent-badge-widget",
  "selectedParents": [1],
    "status": "success"
  },
  "tasks": [
  { "id": "1", "title": "Frontend: Render Spec Agent K badge widget", "status": "done" }
  ]
}
```

Step 4 — View the demo site
---------------------------

Open `examples/quickstart/site/index.html` in your browser. After tasks complete, refresh the page to see the Spec Agent K badge rendered inside `#kibo-agent-badge-container`.

Step 5 — Validate (optional but recommended)
--------------------------------------------

- Spec validator

```text
@~/.agent-os/instructions/core/spec-validator.md

[spec_validation]
SPEC_PATH: @.agent-os/specs/YYYY-MM-DD-add-kibo-agent-badge-widget/spec.md
[/spec_validation]
```

- Tasks validator

```text
@~/.agent-os/instructions/core/tasks-validator.md

[tasks_validation]
TASKS_PATH: @.agent-os/specs/YYYY-MM-DD-add-kibo-agent-badge-widget/tasks.md
[/tasks_validation]
```

Next steps
----------

- See smoke tests: [smoke-tests.md](./smoke-tests.md)
- Learn modes and options: [create-spec-usage.md](./create-spec-usage.md)
- Troubleshoot: [troubleshooting.md](./troubleshooting.md)
- Glossary: [glossary.md](./glossary.md)
- Configuration: [configuration.md](./configuration.md)
- Installation: [installation.md](./installation.md)
- Architecture & customization: [architecture.md](./architecture.md)
- After running execute-tasks, check `context/tasks-summary.json` for a compact run summary.

Using Jira? See: [Jira Extension Guide](./jira-extension.md)

Existing Project Quickstart (Analyze Product)
--------------------------------------------

If you’re integrating into an existing repo, run discovery-first to reuse existing context and avoid re-asking for info.

1) Optional: run discovery yourself (read-only unless cache is missing)

```bash
# from the project root
bash tools/discover-product-context.sh --write-if-missing

# or target another project path
bash tools/discover-product-context.sh /absolute/path/to/project --write-if-missing
```

2) Optional: if discovery is insufficient and you want to bootstrap minimal product docs

```bash
bash tools/discover-product-context.sh /absolute/path/to/project --init-product --write
```

3) Run analyze-product in your editor

```text
@~/.agent-os/instructions/core/analyze-product.md

[analyze_inputs]
auto_init_product: false
[/analyze_inputs]
```

Notes:

- Discovery reads `.agent-os/product/*`, `CLAUDE.md`, `docs/architecture.md`, `README.md`, and build files to infer stack.
- On Windows, use Git Bash or WSL. The script can use `jq.exe` under WSL and accepts Windows paths like `C:/path/...`.
- See details: [context-discovery.md](./context-discovery.md)

Context optimizations (FYI)
---------------------------

- Lite-first reads (`spec-lite.md`, `context/facts.md`)
- Section-level manifests for targeted reloads
- Extension registry caching using front-matter-only reads

External resources
------------------

- Spec Agent K website (docs, installation, best practices): [buildermethods.com/agent-os](https://buildermethods.com/agent-os)
- Builder Briefing newsletter: [buildermethods.com](https://buildermethods.com)
- YouTube (Brian Casel): [youtube.com/@briancasel](https://youtube.com/@briancasel)
