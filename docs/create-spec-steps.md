---
title: Create‑Spec – Step by Step
version: 1.0
lastUpdated: 2025-08-16
---

This page documents the complete create‑spec flow so you can see what happens, in what order, and why. It mirrors `instructions/core/create-spec.md` and stays high level for quick reference.

Overview
--------

- Goal: Generate a feature spec and task plan aligned to mission, roadmap, and standards.
- Outputs: spec.md, spec-lite.md, sub-specs (technical, API, DB as needed), tasks.md, context files (facts, manifest, meta).
- Determinism: Section counts/order enforced; validators repair when needed.

Steps (core)
------------

0.9 Extensions Discovery Report (debug, optional)

- Emit a report listing loaded/skipped extension files and the merged step order; save to `[spec_folder_path]/debug/extensions-discovery.txt`.

1 Spec Initiation

- Validate inputs (main_idea, stories, scope, deliverables). Support "what's next?" roadmap initiation or a specific idea.

2 Context Gathering (conditional)

- Read `mission-lite.md` and `standards/tech-stack.md` only if not already in context; cache selective reads in `context/manifest.json`.

3 Requirements Clarification

- Ask numbered questions to clarify scope or technical details; proceed when clear.

4 Date Determination

- Determine YYYY-MM-DD for naming.

5 Spec Folder Creation

- Create `[spec_folder_path]` and subfolders; normalize name (<= 5 words, kebab-case) using the name normalizer.

6 Create spec.md

- Write spec with sections in strict order: Overview, User Stories, Spec Scope, Out of Scope, Expected Deliverable.
- Run spec validator; auto-repair if needed.

6.1 Emit Lite Context Artifacts

- Write `meta.json` (including `requires_db_changes`/`requires_api_changes` and section counts), `context/facts.md`, and `context/manifest.json`.

7 Create spec-lite.md

- Create a concise summary for fast context loads.

7.1 Update Manifest for spec-lite.md

- Add hash and lastModified for `spec-lite.md` in `context/manifest.json`.

8 Create Technical Specification

- Write `sub-specs/technical-spec.md` (add external dependencies section only if needed).

9 Create Database Schema (conditional)

- If `requires_db_changes` true, create `sub-specs/database-schema.md` with schema changes, migrations, and rationale.

10 Create API Specification (conditional)

- If `requires_api_changes` true, create `sub-specs/api-spec.md` with endpoints, request/response, validation, and errors.

11 User Review

- Ask the user to review `spec.md`, `spec-lite.md`, and sub-specs; pause before tasks are created.

12 Create tasks.md

- After approval, create `tasks.md` with 1–5 parents, <= 8 subtasks each, tests-first and verify-last.
- NEW: selectively consult `sub-specs/api-spec.md` and `sub-specs/database-schema.md` (gated by `meta.json` flags or file presence) to ensure API/DB requirements shape the tasks.
- Ordering principles include preferring backend flow when applicable: DB → Repository → Handler → API.

12.1 Validate tasks.md

- Run tasks validator to normalize numbering and required items.

12.2 Update Facts with First Task Summary

- Append Task 1 summary to `context/facts.md` and update manifest hashes.

13 Decision Documentation (conditional)

- Evaluate mission/roadmap deviations without loading `decisions.md` into context; draft/update only with user approval.

14 Execution Readiness Check

- Present a readiness summary and ask to proceed with executing Task 1.

Extensions touchpoints
----------------------

- 0.9 Discovery report (debug)
- 11.9 Task organization hints (optional): pre-creation guidance and backend flow hinting
- 12.05 Enforce preferred order (optional): post-creation stable reorder + validator

Notes
-----

- Lite-first reads: prefer spec-lite and targeted sections; respect `context/manifest.json` hashes.
- Idempotency: ask before overwriting existing files.
- Safety: never auto-load `decisions.md` during planning.
