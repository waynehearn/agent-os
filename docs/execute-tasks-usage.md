---
title: Execute Tasks – Usage and Details
version: 1.0
lastUpdated: 2025-08-16
---

Run one or more tasks from a spec. This page covers both the task loop (execute‑tasks) and the per‑task flow (execute‑task) it invokes.

Quick links: [Analyze Product](./analyze-product-usage.md) • [Plan Product](./plan-product-usage.md) • [Create Spec](./create-spec-usage.md)

> Using Jira (extension): If your spec was created from Jira, see [docs/jira-extension.md](./jira-extension.md) for re‑sync behavior and comment modes.

## Where it fits

- After create‑spec generates `tasks.md`, use execute‑tasks to implement features.
- Optional: you can run only specific parents or a single subtask for tight control.
- Benefits: lite‑first context loading, TDD flow, minimal token footprint, and a compact run summary.

## Basic usage

Run next uncompleted parent task for a spec:

```text
@~/.agent-os/instructions/core/execute-tasks.md

[execution_context]
spec_folder_path: @.agent-os/specs/YYYY-MM-DD-spec-name
[/execution_context]
```

## Try it (bash)

These optional bash commands help with debugging a run. Use Git Bash on Windows, WSL, or any Unix shell.

Verify jq (pretty printing for logs and summaries):

```bash
bash tools/verify-jq.sh
```

Follow the execution trace (if you enabled debug_subagents):

```bash
bash tools/trace-tail.sh ".agent-os/specs/YYYY-MM-DD-spec-name/debug/exec-trace" --follow
```

Inspect the tasks summary after a run:

```bash
jq . ".agent-os/specs/YYYY-MM-DD-spec-name/context/tasks-summary.json"
```

Run specific parents or a targeted subtask:

```text
@~/.agent-os/instructions/core/execute-tasks.md

[execution_context]
spec_folder_path: @.agent-os/specs/YYYY-MM-DD-spec-name
specific_tasks:
  - 1
execution_notes: >
  Execute only subtask 1.1 and stop after verifying tests.
[/execution_context]
```

## What it does (execute‑tasks)

From `instructions/core/execute-tasks.md`:

1. Task assignment
   - Pick tasks explicitly or default to next uncompleted parent.
2. Context analysis (lite‑first)
   - Always: load current parent task subtree from `tasks.md`.
   - Conditionally: `mission-lite.md`, `spec-lite.md`, `technical-spec.md`, `api-spec.md`, `database-schema.md` using a hybrid API/DB heuristic and manifest hashes for selective reads.
3. Dev server check (optional)
4. Git branch management (git‑workflow subagent)
5. Task execution loop
   - For each parent task, call execute‑task with the task subtree.
6. Run full test suite (test‑runner)
7. Git workflow (commit/push/PR)
8. Roadmap progress check (conditional)
9. Completion summary → `context/tasks-summary.json`

## What it does (execute‑task)

From `instructions/core/execute-task.md`:

1. Task understanding
   - Read only the current parent task block and its subtasks.
2. Technical spec review (selective)
3. API spec review (hybrid rule)
4. Database schema review (hybrid rule)
5. Implementation (TDD): tests first → implement → verify
6. Task‑specific test verification (focused run)
7. Update `tasks.md` status

## Artifacts produced

- During/after runs:
  - `context/current-task.md` (optional snippet of current parent)
  - `context/tasks-summary.json` (normalized numbering, first/last subtask presence)
  - `debug/exec-trace/` logs when `debug_subagents: true`

## Inputs and flags

- `spec_folder_path` (required)
- `specific_tasks` (optional) – list of parent numbers
- `execution_notes` (optional) – scope to a subtask; stop after focused tests
- Debug flags: `debug_subagents`, `debug_trace_redact_secrets`, `debug_trace_include_bodies`

## Extensibility and customization

- No extension loader; instead, behavior is controlled by the task text and selective, manifest‑aware reads of sub‑specs.
- You can influence execution via:
  - The content and structure of `tasks.md` (created by create‑spec and normalized by tasks‑validator).
  - API/DB flags in `meta.json` and presence of sub‑specs (hybrid rules).
  - Standards docs (`standards/best-practices.md`, `standards/code-style.md`) consulted selectively.

## Example – run two parents

```text
@~/.agent-os/instructions/core/execute-tasks.md

[execution_context]
spec_folder_path: @.agent-os/specs/2025-08-12-location-patch-support
specific_tasks:
  - 1
  - 3
[/execution_context]
```
