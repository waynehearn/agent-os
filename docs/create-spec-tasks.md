---
title: How tasks are created (create-spec)
version: 1.0
lastUpdated: 2025-08-16
---

This guide explains exactly how `tasks.md` is generated during the create‑spec command (Step 12), what inputs influence it, and how validation and optional extensions shape the result.

## Where it fits

- Deep dive for Step 12 of create‑spec. Use alongside `docs/create-spec-usage.md` and `docs/create-spec-steps.md`.
- Subagent: file-creator
- Target file: `@[spec_folder_path]/tasks.md`
- Precondition: user approves the spec and sub-specs in Step 11

## Inputs that influence task generation

- Spec artifacts:
  - `spec.md` (sections and expected deliverables set context)
  - `spec-lite.md` (summary)
- Meta and context:
  - `meta.json` flags: `requires_api_changes`, `requires_db_changes`
  - `context/manifest.json` (hashes to avoid re-reading unchanged files)
- Sub-specs (selective, minimal reads):
  - `sub-specs/api-spec.md` (endpoints, request/response, validation, errors)
  - `sub-specs/database-schema.md` (tables, columns, migrations, constraints)
- Optional extension variables (if enabled):
  - `task_hints: true` to activate ordering hints
  - `preferred_major_order` (e.g., `DB,API,UI`)
  - `preferred_backend_flow` (default `DB,Repository,Handler,API`)

## Generation rules (baseline)

- 1–5 parent tasks (major tasks)
- Each parent up to 8 subtasks
- TDD shape: first subtask writes tests; last verifies tests
- Grouping by feature/component; consider dependencies; build incrementally

## API/DB awareness (selective reads)

- When `requires_api_changes` is true or `sub-specs/api-spec.md` exists:
  - Read only the relevant endpoint sections (method/path, request/response, validation, errors)
  - Ensure at least one API parent task exists with tests-first and a verify step
- When `requires_db_changes` is true or `sub-specs/database-schema.md` exists:
  - Read only the relevant schema/migration sections
  - Ensure at least one DB parent task exists with migration, apply, and verification
- Reads are manifest-aware: if the file hash hasn’t changed, skip re-reading

## Ordering and backend flow

- Core ordering principles include considering technical dependencies and preferring backend flow when applicable: DB → Repository → Handler → API
- With the Task Organization Hints extension enabled (`task_hints: true`):
  - Pre-creation guidance (Step 11.9) nudges the generator toward `preferred_major_order` and `preferred_backend_flow`
  - Post-creation enforcement (Step 12.05) can stably reorder only the top-level tasks, and gently nudge backend/API subtasks to follow `DB → Repository → Handler → API` when obvious

## Validation and normalization

- Immediately after creation, `tasks-validator.md` runs (Step 12.1) to normalize:
  - Structure: parents as top-level checklist items; subtasks indented
  - Numbering: sequential N and N.m
  - Counts: 1–5 parents; ≤ 8 subtasks per parent
  - Required subtasks: ensure tests-first and verify-last exist (added if missing)
  - Blocked lines allowed as notes (e.g., `⚠️ Blocking issue: ...`)

## Idempotency

- If `tasks.md` already exists, the flow asks before overwrite
- Validators make non-destructive, deterministic fixes; diffs are predictable

## See also

- Step-by-step overview: `docs/create-spec-steps.md`
- Core rules: `instructions/core/create-spec.md` (Step 12)
- Validator details: `instructions/core/tasks-validator.md`
- Task ordering hints (extension): `instructions/extensions/create-spec/task-organization-hints.md`
