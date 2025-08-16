---
title: How modes and settings shape tasks
version: 1.0
lastUpdated: 2025-08-16
---

This page explains how workflow modes and key settings influence `tasks.md`, and how the LLM derives tasks from the inputs and outputs of the create-spec process. It complements (and does not repeat) the mechanics covered in `docs/create-spec-tasks.md`.

Scope
-----

- Focus: what changes in task generation across modes (express, standard, investigate)
- Focus: which inputs most strongly shape parent tasks and subtasks
- Not repeated here: validator internals, file I/O steps, or template details (see `create-spec-tasks.md`)

Modes → task generation behavior
--------------------------------

- Express
  - Goal: speed for simple/low-risk specs
  - Inputs used: spec.md sections + meta flags (`requires_api_changes`, `requires_db_changes`), spec-lite, facts; sub-specs are not created or read
  - Effect on tasks: parents are inferred from deliverables and flags; still enforces tests‑first and verify‑last via validator
  - When to choose: small UI/UX work, instrumentation, pattern-conforming endpoints

- Standard
  - Goal: thoroughness for complex/medium‑risk specs
  - Inputs used: everything from Express plus selective reads of sub-specs (API/DB) when present; manifest governs minimal reads
  - Effect on tasks: richer, more specific parents (per endpoint/table), with details pulled from sub-specs (method/path, migrations, constraints)

- Investigate
  - Goal: produce investigation artifacts instead of an implementation spec
  - Outputs: investigation report, findings summary, optional Jira tickets and ready-to-use create-spec templates
  - Effect on tasks: `tasks.md` is not created in this mode. To get tasks, run create-spec later (Express or Standard) using the generated templates or ticket context.

Settings that shape tasks (most impactful)
-----------------------------------------

- `requires_api_changes` / `requires_db_changes`
  - Express: directly triggers API/DB parents without sub-specs
  - Standard: also enables selective reads of `sub-specs/api-spec.md` and `sub-specs/database-schema.md` for details

- Task Organization Hints extension (optional)
  - `task_hints: true` activates ephemeral guidance during generation
  - `preferred_major_order`: stable reorder of just top-level tasks (post-creation)
  - `preferred_backend_flow`: gentle nudge inside backend/API parents (DB → Repository → Handler → API)
  - See: `instructions/extensions/create-spec/task-organization-hints.md`

- `non_interactive`
  - Skips prompts/approvals but does not change task content; defaults are chosen deterministically

- `overwrite_existing`
  - Affects idempotency/overwrite prompts only; no effect on task content

Derivation map (inputs → task shape)
------------------------------------

- Expected Deliverables → Parent tasks
  - Each externally verifiable outcome tends to produce 1 parent or a tightly grouped set
  - Titles echo the deliverable; subtasks begin with tests and end with verification

- API work (flagged or detected)
  - Express: create an API parent with subtasks such as “Write endpoint tests”, “Implement endpoint”, “Validate request/response”, “Verify tests”
  - Standard: split by endpoint when `api-spec.md` defines multiple; include method/path and validation/error details

- DB work (flagged or detected)
  - Express: create a DB parent with subtasks like “Create migration”, “Apply migration”, “Update repository”, “Verify data behavior”
  - Standard: reflect concrete entities/migrations from `database-schema.md` (tables, columns, indexes, constraints)

- UI/UX deliverables
  - Derive a UI parent: “Write component/flow tests”, “Implement UI”, “Accessibility checks”, “Verify tests”

- Jira‑driven inputs (via extension)
  - Jira fields seed spec content (summary, AC, components). The task engine is unchanged, but clearer deliverables/components produce cleaner parent grouping and names.

With and without sub-specs
--------------------------

- Without sub-specs (Express):
  - The engine infers API/DB parents from flags and deliverable wording; specifics (e.g., exact endpoint fields) remain in the tests and implementation steps rather than separate sub-spec files.

- With sub-specs (Standard):
  - The engine reads only the needed sections to enrich tasks, typically yielding one parent per endpoint (API) or per migration/theme (DB) with precise method/path or DDL cues.

Minimal examples (abbreviated)
------------------------------

- Express, manual inputs (API only)

  Inputs:
  - Deliverable: “POST /v1/events creates an Event and returns 201 with JSON body”
  - Flags: `requires_api_changes: true`, `requires_db_changes: false`

  Resulting parents (titles only):
  - 1. API: POST /v1/events — tests, implementation, validation, verify

- Standard, API + DB with sub-specs

  Inputs:
  - `api-spec.md` defines POST /v1/events and GET /v1/events/{id}
  - `database-schema.md` defines Events table + index

  Resulting parents (titles only):
  - 1. Database: Events table migration and index — migrate, apply, verify
  - 2. API: POST /v1/events — tests, implement, error handling, verify
  - 3. API: GET /v1/events/{id} — tests, implement, error handling, verify

Per‑mode examples (end‑to‑end)
------------------------------

- Express (UI change, no API/DB)

  Inputs (instruction block):

  ```text
  @~/.agent-os/instructions/core/create-spec.md

  [spec_inputs]
  mode: express
  main_idea: "Add inline validation to email field on signup form"
  expected_deliverables:
    - "Form prevents submission with invalid email and shows accessible error message"
  requires_api_changes: false
  requires_db_changes: false
  [/spec_inputs]
  ```

  Resulting parents (titles only):
  - 1. UI: Email validation on signup — tests, implement, accessibility check, verify

- Standard (API + DB with sub‑specs)

  Inputs (instruction block):

  ```text
  @~/.agent-os/instructions/core/create-spec.md

  [spec_inputs]
  mode: standard
  main_idea: "Create Events API and persistence"
  expected_deliverables:
    - "POST /v1/events returns 201 with created Event"
    - "GET /v1/events/{id} returns 200 with Event JSON"
  requires_api_changes: true
  requires_db_changes: true
  [/spec_inputs]
  ```

  Effect: sub-specs are generated and selectively read for task enrichment.

  Resulting parents (titles only):
  - 1. Database: Events table migration and index — migrate, apply, verify
  - 2. API: POST /v1/events — tests, implement, error handling, verify
  - 3. API: GET /v1/events/{id} — tests, implement, error handling, verify

- Investigate (no tasks until you convert findings)

  Inputs (instruction block):

  ```text
  @~/.agent-os/instructions/core/create-spec.md

  [spec_inputs]
  mode: investigate
  investigation_type: performance
  symptoms:
    - "Dashboard loads in 8+ seconds"
  generate_tickets: true
  ticket_project_key: PERF
  [/spec_inputs]
  ```

  Effect: emits investigation artifacts and optional Jira tickets + ready-to-use create-spec templates. Run create-spec (Express or Standard) with one of those templates to produce `tasks.md`.

Flags behavior by mode
----------------------

- Express
  - `requires_api_changes: true` → Add at least one API parent (even without `api-spec.md`). Multiple API parents are inferred from deliverables if they clearly describe distinct endpoints.
  - `requires_db_changes: true` → Add a DB parent (migration/apply/verify). Additional DB parents may appear only if deliverables imply separate migrations.
  - Both false → Parents derive from deliverables; API/DB parents appear only if deliverables explicitly indicate API/DB work.

- Standard
  - Flags true → Ensure API/DB parents exist and generate sub-specs; tasks are enriched from those sub-specs (method/path, DDL, constraints).
  - Flags false but sub-specs exist → Tasks still include API/DB parents, because presence of sub-specs implies the work.
  - Multiple endpoints/tables in sub-specs → Typically one parent per endpoint and one per migration/theme.

Task ordering vs determination (extension)
-----------------------------------------

- The Task Organization Hints extension influences ordering and grouping, not whether a task exists.
  - Pre‑creation (Step 11.9): ephemeral hints nudge generator toward `preferred_major_order` and backend flow.
  - Post‑creation (Step 12.05): stable reorder of top‑level parents only; preserves subtask lists; re‑numbers; re‑validates.
  - It never creates or removes parents; it may gently reorder obvious backend/API subtasks without changing wording.

Cross‑references
----------------

- Mechanics and validator details: `docs/create-spec-tasks.md`
- Usage and modes overview: `docs/create-spec-usage.md`
- Task ordering hints: `instructions/extensions/create-spec/task-organization-hints.md`
- Execute flow (how tasks run): `instructions/core/execute-tasks.md`
