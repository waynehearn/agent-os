---
description: Task organization hints for Spec Agent Kibo (create-spec)
targets: ["create-spec"]
version: 1.0
encoding: UTF-8
vendor: local
---

<!-- markdownlint-disable MD033 MD032 MD007 MD022 MD023 MD041 -->

# Task Organization Hints Extension (create-spec)

<!-- Optional extension that nudges task grouping/order during tasks.md creation. Loaded only when front matter matches targets and (optionally) requires. -->

<variables>
  <task_hints>false</task_hints>
  <!-- Comma-separated desired major task order. Recognized tokens: API, DB, UI, TESTS, DOCS -->
  <preferred_major_order>API,DB,UI</preferred_major_order>
  <!-- Optional detailed backend flow within API-related work: DB->Repository->Handler->API -->
  <preferred_backend_flow>DB,Repository,Handler,API</preferred_backend_flow>
</variables>

<step number="11.9" subagent="context-fetcher" name="task_organization_hints">

## Step 11.9 (Extension): Task organization hints (optional)

Provide lightweight guidance to the task generator before Step 12 runs.

<gate>
  RUN ONLY IF: [task_hints] == true
  FRONT-MATTER SHORT READ: This file is discovered by targets=["create-spec"]. The system reads only front matter to decide loading; variables and steps are parsed only if loaded.
  SAFETY: This step provides hints only; it does not modify files.
  OUTPUTS: ephemeral guidance applied by the subagent generating tasks.md in Step 12.
  LIMITS: Core validators still enforce structure and counts.
  ORDER PREF: Use [preferred_major_order] when applicable; ignore unknown tokens.
  BACKEND FLOW: Within backend/API work, prefer [preferred_backend_flow] (DB → Repository → Handler → API) when feasible.
  SUBTASK SHAPE: Prefer TDD (tests first) and verification last.
  COUNTS: Keep 1–5 major tasks; ≤8 subtasks each.
</gate>

<actions>
  1. PREFER major task order per [preferred_major_order], e.g., API → DB → UI when present in the spec.
  2. FOR EACH major task, recommend this subtask shape:
     - 1: "Write tests for [area]"
     - 2–3: implementation steps (routes/handlers/repos; migrations; UI wiring)
     - last: "Verify all tests pass"
  3. WHEN flags indicate scope:
     - If requires_api_changes == true, ensure an API parent task exists
     - If requires_db_changes == true, ensure a DB parent task exists (migration + apply)
  4. WITHIN BACKEND/API scope, nudge an internal flow: DB → Repository → Handler → API (apply as subtask ordering hints or by splitting major tasks if appropriate and size allows)
  5. SIZE discipline:
     - Prefer 1–5 major tasks and ≤8 subtasks; merge overly granular items into coherent units
  6. NUMBERING:
     - Maintain decimal subtask numbering (1.1, 1.2, ...); do not skip numbers
</actions>

</step>

<step number="12.05" subagent="context-fetcher" name="enforce_task_order">

## Step 12.05 (Extension): Enforce preferred order (optional)

Normalize ordering after tasks.md is created.

<gate>
  RUN ONLY IF: [task_hints] == true
</gate>

<inputs>
  - tasks_path: @[spec_folder_path]/tasks.md
  - order_preference: [preferred_major_order]
  - backend_flow: [preferred_backend_flow]
</inputs>

<actions>
  1. READ tasks.md major tasks and attempt a stable reorder to match [preferred_major_order] when those categories exist.
  2. PRESERVE each major task’s subtasks and internal order.
  3. WITHIN backend/API-related parents, attempt a gentle subtask nudge to reflect [backend_flow] where it’s safe (e.g., group DB migration before repository scaffolding, before handler, before API route wiring), without renaming existing items.
  4. RE-NUMBER major tasks sequentially (1..N) and subtasks (X.1..X.M) after reordering.
  5. RUN validator to ensure structure and numbering are correct:
     EXECUTE: @~/.agent-os/instructions/core/tasks-validator.md with TASKS_PATH=@[spec_folder_path]/tasks.md
</actions>

<notes>
  - This step is conservative: if categories cannot be inferred, it leaves the original order intact.
  - Category inference uses simple keyword matching in the major task description (e.g., "API", "DB", "UI").
  - Unknown tokens in [preferred_major_order] are ignored.
  - Subtask nudging does not change wording; it only reorders when an obvious DB/Repository/Handler/API sequence can be inferred from keywords like "migration", "repository", "handler", "controller", "route".
</notes>

</step>
