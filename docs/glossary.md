---
title: Spec Agent Kibo – Glossary
version: 1.0
lastUpdated: 2025-08-14
---

A quick reference for key terms used across the create-spec and execute-tasks flows.

Core objects
------------

- Spec (folder)
  - The generated feature spec directory under `@.agent-os/specs/YYYY-MM-DD-<spec-name>/`.

- spec_folder_path
  - A normalized path alias used in instructions that points to the spec folder.

- spec.md
  - The canonical, detailed specification. Core sections in strict order: Overview, User Stories, Scope, Deliverables, Technical Details. Conditional sections (appended when applicable): API Specification, Database Changes.

- spec-lite.md
  - A concise summary of the spec for efficient AI context use.

- sub-specs/
  - Subdirectory containing topic-specific specs:
    - technical-spec.md – Implementation approach and key design choices
    - database-schema.md – Schema diffs/new tables (created if `requires_db_changes: true`)
    - api-spec.md – API contracts (created if `requires_api_changes: true`)

- tasks.md
  - The task breakdown for implementing the spec.

Lite-first context artifacts
----------------------------

- context/facts.md
  - A short, human-readable summary of mission/spec facts for fast context. If mission docs are absent, it will include: "Mission (lite): N/A".

- context/manifest.json
  - Tracks sha256 and lastModified for key files and sections so execution flows can skip re-reading unchanged files and load only changed sections.

- context/meta.json
  - Tiny JSON containing counts/flags (e.g., section counts) used for quick checks.

- context/tasks-summary.json
  - A small summary emitted by execute-tasks with high-level run info and per-task status.
  - Example (truncated):
    {"run":{"specFolderPath":"@.agent-os/specs/2025-08-14-add-events-post-endpoint","selectedParents":[1,4],"status":"success"},"tasks":[{"id":"1","title":"API: POST /api/v1/events","status":"done"}]}

Tasks and numbering
-------------------

- Parent task
  - A top-level task (e.g., `1`, `2`).

- Subtask
  - A nested task under a parent (e.g., `1.1`, `1.2`).

- Targeted execution
  - Running only selected parent tasks via `specific_tasks`, or a single subtask via `execution_notes`.

Validation and determinism
--------------------------

- spec-validator.md
  - Verifies and repairs `spec.md` section order and count constraints; run with `SPEC_PATH`.

- tasks-validator.md
  - Normalizes `tasks.md` numbering and structure; run with `TASKS_PATH`.

- overwrite_existing (boolean)
  - Controls idempotency for create-spec when files exist (ask/overwrite/skip behavior).

- requires_db_changes / requires_api_changes (booleans)
  - Flags that drive conditional creation of `database-schema.md` and `api-spec.md`.

Initiation modes
----------------

- what's next?
  - Roadmap-driven trigger that selects the next uncompleted item from `@.agent-os/product/roadmap.md`.

- jira_inputs
  - Jira-driven mode that maps a Jira issue (`jira_issue_key`) into spec inputs; supports overrides (see [Jira key reference](jira-extension.md#canonical-jira-key-reference)).

- spec_inputs
  - Manual mode where all inputs are provided explicitly.

Execution context
-----------------

- execute-tasks
  - Flow that runs tasks from `[spec_folder_path]/tasks.md`.

- [execution_context]
  - Block for passing `spec_folder_path` and `specific_tasks` (optional) into execute-tasks. `execution_notes` can scope to a subtask and stop after tests.

Project docs
------------

- mission-lite.md
  - High-level product pitch for context alignment.
  - Optional. Flows proceed without it; facts.md will note N/A.

Architecture (example scenario)
-------------------------------

- API layer → Domain handler layer → Repo layer
  - Common layering used in the Web API example. Domain layer enforces validation; repo layer persists (may require a specific NuGet package and DI wiring).
