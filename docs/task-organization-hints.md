---
title: Task Organization Hints Extension
version: 1.0
lastUpdated: 2025-08-15
---

Use this extension to nudge how tasks.md is grouped and ordered without modifying core files.

Overview
--------

The Task Organization Hints extension:

- Injects pre-generation guidance right before tasks are created (Step 11.9)
- Optionally enforces preferred top-level ordering right after creation (Step 12.05)
- Can prefer an internal backend flow (DB → Repository → Handler → API) for API-related work
- Remains optional and safe to skip; if not enabled, core behavior is unchanged

Where the file lives
--------------------

Place the extension file in one of these locations so create-spec can discover it:

- Home scope: `@~/.agent-os/instructions/extensions/create-spec/task-organization-hints.md`
- Project scope: `@.agent-os/instructions/extensions/create-spec/task-organization-hints.md`

This repository already includes the project-scoped file at:
`instructions/extensions/create-spec/task-organization-hints.md`

Front matter short read (load/skip)
-----------------------------------

The system scans extension files and reads only their front matter to decide whether to load them.
This extension declares:

```yaml
---
description: Task organization hints for Spec Agent Kibo (create-spec)
targets: ["create-spec"]
version: 1.0
vendor: local
---
```

Because `targets` includes `create-spec`, it’s eligible to be loaded into that flow. No additional `requires` are needed. If `targets` were missing or different, it would be skipped without parsing the body.

Variables
---------

- `task_hints` (bool, default false): master switch; enable in your input block to activate.
- `preferred_major_order` (string): comma-separated category order to prefer. Supported tokens: `API`, `DB`, `UI`, `TESTS`, `DOCS`. Unknown tokens are ignored.
- `preferred_backend_flow` (string): internal order to prefer within backend/API work. Default: `DB,Repository,Handler,API`.

Enable the extension
--------------------

Add these to your create-spec input block (e.g., Jira inputs or manual spec inputs):

```text
@~/.agent-os/instructions/core/create-spec.md

[task_hints]
task_hints: true
preferred_major_order: API,DB,UI
preferred_backend_flow: DB,Repository,Handler,API
[/task_hints]
```

Notes:

- The block name is arbitrary; keys are what matter. You can also fold these into your existing inputs block.
- Keep `task_hints: false` by default; turn it on per-run when you want to influence ordering.

What it does
------------

- Step 11.9: Provides ephemeral guidance to the subagent that writes `tasks.md` in Step 12:
  - Prefer the major task order you specify (when categories are present)
  - Encourage a TDD shape for subtasks: tests first, verification last
  - If `requires_api_changes` or `requires_db_changes` are true, ensure corresponding parent tasks exist
  - Within backend/API work, nudge DB → Repository → Handler → API flow where feasible
  - Keep size constraints: 1–5 major tasks, ≤8 subtasks each

- Step 12.05: After `tasks.md` is created, attempt a stable reorder of only the top-level tasks to match your preferred order. It preserves subtask ordering within each parent. Then it re-numbers and re-runs the tasks validator.
  - Within backend/API parents, it can gently reorder obvious DB/Repository/Handler/API subtasks without changing their wording.

Category inference
------------------

The enforcement step uses simple keyword heuristics against each major task title:

- API: words like "API", "endpoint", "controller", "route"
- DB: words like "DB", "database", "schema", "migration"
- UI: words like "UI", "component", "page", "view"
- TESTS: words like "test", "tests", "integration"
- DOCS: words like "docs", "documentation", "readme"

If none match, that task keeps its relative position.

Examples
--------

Minimal enablement:

```text
@~/.agent-os/instructions/core/create-spec.md

[task_hints]
task_hints: true
preferred_major_order: API,DB,UI
[/task_hints]
```

With Jira inputs (combine in the same block):

```text
@~/.agent-os/instructions/core/create-spec.md

[jira_inputs]
jira_issue_key: ABC-1234  # See canonical Jira key reference in docs/jira-extension.md
use_jira_mcp: true
post_spec_to_jira: false

# Task organization hints
task_hints: true
preferred_major_order: API,DB,UI
[/jira_inputs]
```

Debugging extension discovery
-----------------------------

Set `debug_extensions: true` in your inputs to print an Extensions Discovery Report and save it under `@[spec_folder_path]/debug/extensions-discovery.txt`.

References
----------

- Extension file: `instructions/extensions/create-spec/task-organization-hints.md`
- Core flow: `instructions/core/create-spec.md` (see Steps 12–12.2; Step 12 now consults API/DB sub-specs when present)
- Extensions overview: `docs/extensions-quickstart.md`, `instructions/extensions/README.md`
- Jira example: `instructions/extensions/create-spec/atlassian-jira.md`
