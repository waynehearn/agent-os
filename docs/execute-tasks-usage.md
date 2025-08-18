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
debug_subagents: false   # set true to emit NDJSON trace under debug/exec-trace
debug_trace_redact_secrets: true
debug_trace_include_bodies: false
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

## Run inside Claude Code

Use the same instruction block as a slash-command message. Claude Code will read `@~/.agent-os/instructions/core/execute-tasks.md` and apply the `execution_context` you provide.

- Required: `spec_folder_path`
- Optional: `specific_tasks`, `execution_notes`
- Debugging:
  - Set `debug_subagents: true` to emit NDJSON events under `debug/exec-trace/` for the current spec
  - Optional redaction and body inclusion via `debug_trace_redact_secrets`, `debug_trace_include_bodies`

TDD loop note (script-mode only): If you prefer the script implementation while in Claude Code, open the integrated terminal and run the per-task runner with environment flags:

- `ENABLE_TDD_LOOP=1` to enable focused test runs
- `TEST_CMD` to specify your test command
- `TEST_PATTERN` to focus tests (auto-inferred from parent title if omitted)
- `TEST_RETRIES` to retry failing runs

Artifacts (same regardless of where you invoke it):

- context/current-task.md, context/tasks-summary.json, context/tasks-heuristics.json
- context/selected-technical.md; context/selected-api.md/context/selected-db.md when gated
- context/test-run-summary.json when TDD loop is enabled (script-mode)

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
- Debug flags (Claude Code or script-mode): `debug_subagents`, `debug_trace_redact_secrets`, `debug_trace_include_bodies`
- Script-mode TDD envs (optional): `ENABLE_TDD_LOOP`, `TEST_CMD`, `TEST_PATTERN`, `TEST_RETRIES`

Context caching (script-mode)

- The hierarchical context gatherer now supports a shared TTL cache to skip redundant work between runs.
- Flags: `--use-cache` (default), `--no-cache`, `--cache-ttl <seconds>`
- Env: `USE_CACHE=1|0`, `OPERATION_CACHE_TTL=<seconds>`
- Example:

```bash
# Default cache (TTL 1h)
bash tools/context-gatherer.sh --operation execute-tasks gather-context spec out.md

# Disable cache for a run
bash tools/context-gatherer.sh --no-cache gather-context spec out.md

# Custom TTL (5 minutes)
OPERATION_CACHE_TTL=300 bash tools/context-gatherer.sh gather-context product out.md
```

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
