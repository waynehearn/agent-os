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
  - The canonical, detailed specification. Must contain sections in this strict order: Overview, User Stories, Spec Scope, Out of Scope, Expected Deliverable.

- spec-lite.md
  - A concise summary of the spec for efficient AI context use.

- sub-specs/
  - Subdirectory containing topic-specific specs:
    - technical-spec.md – Implementation approach and key design choices
    - database-schema.md – Schema diffs/new tables (created if `requires_db_changes: true`)
    - api-spec.md – API contracts (created if `requires_api_changes: true`)

- tasks.md
  - The task breakdown for implementing the spec.

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
  - Jira-driven mode that maps a Jira issue (`jira_issue_key`) into spec inputs; supports overrides.

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

Architecture (example scenario)
-------------------------------

- API layer → Domain handler layer → Repo layer
  - Common layering used in the Web API example. Domain layer enforces validation; repo layer persists (may require a specific NuGet package and DI wiring).
