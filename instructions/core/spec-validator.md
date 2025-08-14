---
description: Spec Validator for Spec Agent Kibo
globs:
alwaysApply: false
version: 1.0
encoding: UTF-8
---

<!-- markdownlint-disable MD033 MD032 MD007 MD022 MD023 MD034 MD040 -->

# Spec Validator

## Overview

Validate and, if needed, automatically repair a spec document to match project standards. Designed to be invoked from create-spec and execute-tasks flows.

<variables>
  <target_spec>[SPEC_PATH]</target_spec>
</variables>

<contract>
  <inputs>
    - target_spec: absolute or @-prefixed path to spec.md
  </inputs>
  <outputs>
    - validation_result: PASS | FIXED | FAIL
    - details: list of applied fixes or missing items
  </outputs>
  <error_modes>
    - file_missing: skip with note
    - unreadable: report FAIL
  </error_modes>
</contract>

<validation_rules>
  <required_sections_order>
    - Overview
    - User Stories
    - Spec Scope
    - Out of Scope
    - Expected Deliverable
  </required_sections_order>
  <counts>
    - user_stories: 1-3
    - spec_scope_items: 1-5
    - expected_deliverables: 1-3
  </counts>
  <tone>
    - concise, declarative
    - aligned with project style
  </tone>
</validation_rules>

<process_flow>

<step number="1" name="load_spec">

### Step 1: Load spec.md

Attempt to load target_spec. If file missing, return validation_result=SKIP and note.

</step>

<step number="2" name="structure_validation">

### Step 2: Section Order Validation

Check presence and exact order of required sections. If sections are missing or out of order, reorder existing content and insert minimal placeholders for missing sections.

</step>

<step number="3" name="counts_validation">

### Step 3: Counts Validation

Within sections:
  - User Stories: ensure 1-3 stories; if >3, keep top 3 by clarity; if 0, synthesize 1 from Overview.
  - Spec Scope: ensure 1-5 numbered items; trim extras or add placeholders.
  - Expected Deliverable: ensure 1-3 numbered, browser-testable outcomes; trim or synthesize from scope.

</step>

<step number="4" name="tone_normalization">

### Step 4: Tone Normalization

Tighten language to concise, declarative phrasing. Do not change meaning.

</step>

<step number="5" name="write_back_and_report">

### Step 5: Write Back and Report

If changes applied, write back to target_spec and set validation_result=FIXED. If no changes needed, set validation_result=PASS. If unrecoverable issues, set FAIL with details.

<summary_template>
  ## Spec Validation Summary

  - Result: [PASS|FIXED|FAIL|SKIP]
  - File: [target_spec]
  - Fixes Applied:
    - [LIST_OF_FIXES_OR "none"]
  - Notes: [DETAILS]
</summary_template>

</step>

</process_flow>
