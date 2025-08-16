---
description: Deterministic Spec Name Normalizer for Spec Agent K
globs:
alwaysApply: false
version: 1.0
encoding: UTF-8
---

<!-- markdownlint-disable MD033 MD032 MD007 MD022 MD023 MD034 MD040 -->

# Spec Name Normalizer

## Overview

Produce a deterministic, kebab-case spec name (≤ 5 words) from a user-provided title or the main idea. Ensures stable folder/branch names.

<variables>
  <input_name>[INPUT_NAME]</input_name>
  <normalized_name>[OUTPUT_SPEC_NAME]</normalized_name>
</variables>

<rules>
  - Lowercase all letters
  - Replace any non-alphanumeric characters with spaces
  - Split on whitespace, filter out empty tokens
  - Keep the first 5 tokens; do not apply stopword removal (determinism)
  - Join with single hyphens
  - Collapse multiple hyphens to one, trim hyphens at ends
  - If result is empty, use "feature-spec"
</rules>

<collision_handling>
  - If @.agent-os/specs/[CURRENT_DATE]-[OUTPUT_SPEC_NAME] already exists:
    ASK user to overwrite per idempotency rules; on "no", suggest appending "-2" and proceed if confirmed.
</collision_handling>

<process_flow>

<step number="1" name="sanitize">

### Step 1: Sanitize

Convert input_name to lowercase. Replace all non-alphanumeric with spaces. Split to tokens.

</step>

<step number="2" name="truncate_and_join">

### Step 2: Truncate and Join

Take the first 5 tokens. Join with hyphens. Collapse consecutive hyphens. Trim leading/trailing hyphens. Fallback to "feature-spec" if empty.

</step>

<step number="3" name="emit">

### Step 3: Emit

Return normalized_name as [OUTPUT_SPEC_NAME].

</step>

</process_flow>
