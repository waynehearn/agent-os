---
description: Tasks Validator for Spec Agent Kibo
globs:
alwaysApply: false
version: 1.0
encoding: UTF-8
---

<!-- markdownlint-disable MD033 MD032 MD007 MD022 MD023 MD034 MD040 -->

# Tasks Validator

## Overview

Validate and normalize tasks.md so it follows the expected structure, numbering, status marks, and count limits.

<variables>
  <target_tasks>[TASKS_PATH]</target_tasks>
</variables>

<contract>
  <inputs>
    - target_tasks: absolute or @-prefixed path to tasks.md
  </inputs>
  <outputs>
    - validation_result: PASS | FIXED | FAIL | SKIP
    - details: list of applied fixes or missing items
  </outputs>
  <error_modes>
    - file_missing: SKIP with note
    - unreadable: FAIL with reason
  </error_modes>
</contract>

<validation_rules>
  <major_tasks>
    - count: 1-5
    - format: "- [ ] N. Description" or "- [x] N. Description"
    - numbering: sequential starting at 1
  </major_tasks>
  <subtasks>
    - per_major_max: 8
    - format: "- [ ] N.m Description" or "- [x] N.m Description"
    - first_subtask: "Write tests for [COMPONENT]" (or equivalent wording)
    - last_subtask:  "Verify all tests pass" (or equivalent wording)
  </subtasks>
  <blocked_format>
    - allow: "⚠️ Blocking issue: ..." lines under a task
  </blocked_format>
</validation_rules>

<process_flow>

<step number="1" name="load_tasks">

### Step 1: Load tasks.md

Attempt to load target_tasks. If file missing, return validation_result=SKIP with note.

</step>

<step number="2" name="structure_and_numbering">

### Step 2: Structure & Numbering

Ensure major tasks are top-level checkboxes and subtasks are indented under the correct major task. Normalize numbering to sequential N and N.m. If numbering conflicts or gaps exist, renumber deterministically.

</step>

<step number="3" name="counts_and_required_items">

### Step 3: Counts & Required Items

- Enforce major task count between 1 and 5; trim extras to 5 with a note, or if 0, synthesize one from spec first deliverable (if available) or a placeholder.
- For each major task, cap subtasks at 8; ensure the presence of first and last subtasks (add if missing). Keep existing middle subtasks.

</step>

<step number="4" name="status_and_blocked_formatting">

### Step 4: Status & Blocked Formatting

Normalize status marks to [ ] or [x]. Preserve ⚠️ Blocking issue lines as notes. Keep content, only adjust formatting.

</step>

<step number="5" name="write_back_and_report">

### Step 5: Write Back and Report

If changes applied, write back and set validation_result=FIXED. If no changes needed, set PASS. On unrecoverable issues, set FAIL with details.

<summary_template>
  ## Tasks Validation Summary

  - Result: [PASS|FIXED|FAIL|SKIP]
  - File: [target_tasks]
  - Fixes Applied:
    - [LIST_OF_FIXES_OR "none"]
  - Notes: [DETAILS]
</summary_template>

</step>

</process_flow>
