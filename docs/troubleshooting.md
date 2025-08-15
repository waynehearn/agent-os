---
title: Spec Agent Kibo – Troubleshooting
version: 1.0
lastUpdated: 2025-08-14
---

This page lists common issues and quick fixes for create-spec and execute-tasks.

Paths/files
-----------

- Spec folder not found after run
  - Confirm the date and normalized name (kebab-case ≤ 5 words)
  - Check `@.agent-os/specs/` for a similarly named folder
  - If you used Jira-driven mode via extension, ensure the extension file exists and `jira_issue_key` was correct

- Sub-specs not created
  - Confirm flags:
    - `requires_db_changes: true` for `sub-specs/database-schema.md`
    - `requires_api_changes: true` for `sub-specs/api-spec.md`

Validation
----------

- Spec sections out of order / missing
  - Run spec validator (repairs order and counts when possible):

```text
@~/.agent-os/instructions/core/spec-validator.md

[spec_validation]
SPEC_PATH: @.agent-os/specs/YYYY-MM-DD-spec-name/spec.md
[/spec_validation]
```

- Tasks structure off (numbering/format)
  - Run tasks validator:

```text
@~/.agent-os/instructions/core/tasks-validator.md

[tasks_validation]
TASKS_PATH: @.agent-os/specs/YYYY-MM-DD-spec-name/tasks.md
[/tasks_validation]
```

Execution
---------

- Wrong tasks executed
  - Open `[spec_folder_path]/tasks.md` and confirm parent task numbers
  - Use `specific_tasks` to target exact parents

- Only run a subtask and stop
  - Use `execution_notes` to scope to a single subtask and stop after its tests

Subagent debug tracing (optional)
---------------------------------

- To trace subagent calls during execution, set `debug_subagents: true` in your execute‑tasks or execute‑task input block.
- Logs are written as NDJSON to:
  - Parent session: `@[spec_folder_path]/debug/exec-trace/session.log`
  - Per parent task: `@[spec_folder_path]/debug/exec-trace/task-[PARENT_TASK_NUMBER].log`
- Controls:
  - `debug_trace_redact_secrets: true` (default) to mask tokens/API keys
  - `debug_trace_include_bodies: false` (default) to avoid large payloads
  - Helper (bash): `tools/trace-tail.sh @.agent-os/specs/YYYY-MM-DD-name/debug/exec-trace --follow` (pretty output if `jq` is installed; otherwise raw lines)

Idempotency & overwrites
------------------------

- Re-running create-spec asks to overwrite
  - This is expected when files exist and `overwrite_existing: false`
  - Set `overwrite_existing: true` to overwrite deterministically (use with care)

Jira mapping (extension)
------------

- Jira fields missing or sparse
  - Provide overrides directly in `[jira_inputs]`
  - Good Jira tickets include: summary (becomes main_idea), acceptance criteria (maps to deliverables), components/labels (tech constraints)

Jira sync (extension)
---------

- Comment not posted
  - Ensure the Jira extension is installed, `post_spec_to_jira: true`, `jira_issue_key` is valid (e.g., ABC-123), and Atlassian MCP is available in your editor
  - If an identical hash footer exists, the flow will skip posting by design
- Comment too large
  - The flow automatically falls back to posting only Overview and Expected Deliverable sections with a repo path reference
- Want changes only
  - Set `jira_comment_mode: summary` (default) to post concise change summaries on subsequent runs; use `diff` for a unified diff

Environment
-----------

- Shell beep doesn’t work
  - Ignore the chime; the printed completion banner is the signal

- Windows path confusion
  - Use the `@`-prefixed logical paths shown in examples; they’re normalized by the flow

- jq not found
  - Some scripts and flows require `jq`.
  - macOS: `brew install jq`
  - Debian/Ubuntu: `sudo apt-get install -y jq`
  - Fedora/RHEL/CentOS: `sudo dnf install -y jq` (or `sudo yum install -y jq`)
  - Arch/Manjaro: `sudo pacman -S jq`
  - Alpine: `sudo apk add --no-cache jq`
  - Windows (Git Bash): download `jq.exe` to `$HOME/.local/bin` and add to PATH; see Installation docs.

Getting help
------------

- See Quickstart: [quickstart.md](./quickstart.md)
- See Smoke Tests: [smoke-tests.md](./smoke-tests.md)
- Usage & modes: [create-spec-usage.md](./create-spec-usage.md)
- Glossary: [glossary.md](./glossary.md)
- Configuration: [configuration.md](./configuration.md)
- Installation: [installation.md](./installation.md)

Diagnostics
-----------

- Not sure if your extension loaded? Set `debug_extensions: true` when running create‑spec to print an Extensions Discovery Report (shows LOADED/SKIPPED and reasons such as missing `mcp:*` capabilities). A copy is saved to `@[spec_folder_path]/debug/extensions-discovery.txt`.
  - The report includes a "Merged step order (preview)" so you can confirm your step numbers land where expected.
  - Each step is tagged with its source: `[core]` or `[ext:<vendor>]`.
