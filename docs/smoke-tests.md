---
title: Spec Agent Kibo – Simple Smoke Tests
version: 1.0
lastUpdated: 2025-08-14
---

This page gives copy‑pasteable, low‑friction tests to validate the create-spec and execute-tasks flows without extra tooling.

What you’ll verify

- Spec creation writes the right files/sections and honors DB/API flags
- Idempotency behavior on re-run
- Targeted task execution with specific task numbers
- Validators keep spec.md and tasks.md normalized

Prereqs

- Instructions folder at `@~/.agent-os/instructions/`
- You’ve reviewed the Jira example in [create-spec-usage.md](./create-spec-usage.md)

Test 1 — Create spec from Jira example (Web API endpoint)
---------------------------------------------------------

Use the Jira-driven example block in `create-spec-usage.md` (the “Concrete Jira example: ASP.NET Core Web API new endpoint”). After you run it, verify the outputs:

Checklist (update date as appropriate):

- Folder exists: `@.agent-os/specs/YYYY-MM-DD-add-events-post-endpoint/`
- Files exist:
  - `spec.md`
  - `spec-lite.md`
  - `sub-specs/technical-spec.md`
  - `sub-specs/database-schema.md` (because `requires_db_changes: true`)
  - `sub-specs/api-spec.md` (because `requires_api_changes: true`)
  - `tasks.md`
  - `context/` (lite-first artifacts)
    - `facts.md` (Mission (lite) may be N/A when starting from Jira)
    - `manifest.json`
    - `meta.json`
- `spec.md` sections are in strict order:
  1) Overview
  2) User Stories
  3) Spec Scope
  4) Out of Scope
  5) Expected Deliverable

Optional: run validators explicitly

- Spec validator

```text
@~/.agent-os/instructions/core/spec-validator.md

[spec_validation]
SPEC_PATH: @.agent-os/specs/YYYY-MM-DD-add-events-post-endpoint/spec.md
[/spec_validation]
```

- Tasks validator

```text
@~/.agent-os/instructions/core/tasks-validator.md

[tasks_validation]
TASKS_PATH: @.agent-os/specs/YYYY-MM-DD-add-events-post-endpoint/tasks.md
[/tasks_validation]
```

Test 2 — Idempotency (overwrite protection)
------------------------------------------

Re-run create-spec for the same spec with `overwrite_existing: false` (as in the example). Expect:

- The flow asks before overwriting existing files or skips them with a note in the summary
- No duplicate files are created

Variation: set `overwrite_existing: true` to confirm it overwrites deterministically (use with care).

Test 3 — Targeted task execution (API + DB only)
------------------------------------------------

Use this to execute only the API endpoint and DB tasks created by the spec. Adjust numbers to match your generated `tasks.md`.

```text
@~/.agent-os/instructions/core/execute-tasks.md

[execution_context]
spec_folder_path: @.agent-os/specs/YYYY-MM-DD-add-events-post-endpoint
specific_tasks:
  - 1   # API endpoint task (adjust number)
  - 4   # DB table/migration task (adjust number)
[/execution_context]
```

Expected:

- Only the selected parent tasks (and their subtasks) are executed
- Completion banner prints; tests pass if included in your flow
- A compact run summary is written to `[spec_folder_path]/context/tasks-summary.json`

Note:

- During execution, the runner may selectively consult `sub-specs/api-spec.md` and `sub-specs/database-schema.md` using a hybrid rule (flag in `meta.json` or API/DB indicators in the current task text). Reads are minimal and manifest-aware.

Test 4 — Minimal subtask run + stop after tests
-----------------------------------------------

Run a single subtask (e.g., 1.1 for controller route/action wiring) and stop after verifying tests.

```text
@~/.agent-os/instructions/core/execute-tasks.md

[execution_context]
spec_folder_path: @.agent-os/specs/YYYY-MM-DD-add-events-post-endpoint
specific_tasks:
  - 1
execution_notes: >
  Execute only subtask 1.1 (controller action + route) and stop after verifying tests for that subtask.
[/execution_context]
```

Expected:

- Only subtask 1.1 runs; flow stops after its tests and reports status

Test 5 — Input validation gate (failure path)
---------------------------------------------

Provide incomplete inputs to `create-spec` to confirm the early validation gate stops and lists missing fields.

```text
@~/.agent-os/instructions/core/create-spec.md

[spec_inputs]
main_idea: ""
initial_user_stories: []
in_scope: []
expected_deliverables: []
[/spec_inputs]
```

Expected:

- The flow refuses to proceed and shows which required fields are missing

Troubleshooting

- If a validator reports issues, rerun it; the flow is designed to repair ordering and counts when possible
- If task numbers don’t match the examples, open your `tasks.md` and pick the correct numbers
- If your shell doesn’t beep, ignore the chime—completion banners still print
