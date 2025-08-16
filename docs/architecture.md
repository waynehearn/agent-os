---
title: Architecture & Customization Guide
version: 1.0
lastUpdated: 2025-08-16
---

Purpose
-------

This guide explains how Spec Agent Kibo is structured, how context is loaded efficiently, and how to safely customize or extend the process. It’s written for both humans and LLMs. LLMs should follow the “LLM operating hints” in each section to stay budget-aware and deterministic.

High-level architecture
-----------------------

- Core flows: `instructions/core/*.md` (plan-product, create-spec, execute-task(s), analyze-product)
- Optional extensions: `instructions/extensions/<flow>/**/*.md` (discovered automatically)
- Standards: `@.agent-os/standards/*` (tech stack, style, best practices)
- Outputs per spec: `@.agent-os/specs/YYYY-MM-DD-<name>/*` (spec files, sub-specs, context)
- Templates (externalized): `templates/*.md` (reusable content blocks referenced by flows)
- Caches & manifests:
  - `templates/extension-registry.json` – extension metadata cache (front-matter only, 1-hour TTL)
  - `templates/enhanced-manifest.json` – schema describing section-level tracking
  - `[spec_folder_path]/context/manifest.json` – per-spec manifest (now section-aware)

Context system (budget-aware)
-----------------------------

The system minimizes tokens by loading context hierarchically and skipping unchanged content.

- Priority levels
  - P1 Essential (< 100 tokens): keys, flags, file list, lite facts
  - P2 Conditional (< 300 tokens): targeted sections needed for the current step
  - P3 Reference (on demand): full files or low-priority references
- Section-level manifest
  - Tracks hashes and token estimates per section of key files (e.g., `spec.md:overview`)
  - Enables selective reload of only changed sections
- Extension registry cache
  - Scans ONLY front matter to decide inclusion and capabilities
  - Stores results for 1 hour; invalidates by hash/mtime

LLM operating hints
-------------------

- Prefer lite-first: `spec-lite.md`, `context/facts.md`, manifest entries
- Read sections by need; stop when budget is reached
- Never preload full documents when hashes indicate no change
- Avoid loading `decisions.md` during planning

Templates and <template_reference>
----------------------------------

Templates are externalized to reduce core instruction size and improve reuse.

- Location: `templates/`
  - `investigation-report.md`, `api-specification.md`, `database-schema.md`, `validation-rules.md`, etc.
- Usage (inside instructions):

```markdown
<template_reference>
  TEMPLATE: @templates/investigation-report.md
  VARIABLES: [SPEC_NAME, INVESTIGATION_TYPE, symptoms]
  POPULATE: All template variables with context data
  FALLBACK: If missing variables, prompt briefly or use deterministic defaults
  BUDGET: prefer P1/P2 context only
</template_reference>
```

Customization paths
-------------------

1) Add or change templates
   - Create/edit files in `templates/`
   - Keep variable names short and documented at the top of the template
   - Reference via `<template_reference>` from core or extension steps

2) Extend flows (no forking)
   - Add files under:
     - Home: `@~/.agent-os/instructions/extensions/<flow>/`
     - Project: `@.agent-os/instructions/extensions/<flow>/`
   - Front matter MUST include `targets: ["<flow>"]`
   - Optional `requires: ["capability"]` lets the loader skip unsupported files using front-matter-only reads
   - Use decimal step numbers (e.g., 1.1, 6.2) to merge cleanly

3) Tune context budgets
   - Default total budget: 4000 tokens
   - Adjust budgets via your runtime/editor configuration or instruction variables (keep P1 small)
   - Treat budgets as ceilings; load only what you need per step

4) Add new section tracking
   - If you introduce new long sections in `spec.md` or sub-specs, register them in the manifest updater so the section hashes and token estimates are tracked

Contracts (inputs/outputs)
--------------------------

- Inputs (common)
  - `main_idea` (1–2 sentences), `initial_user_stories` (1–5), `in_scope` (1–8), `expected_deliverables` (1–5)
  - Flags: `requires_db_changes`, `requires_api_changes`, `overwrite_existing`, optional extension flags (e.g., `use_jira_mcp`)
- Outputs
  - `spec.md`, `spec-lite.md`, sub-specs (`technical-spec.md`, conditional `database-schema.md`, `api-spec.md`)
  - `context/manifest.json` (section-aware), `context/facts.md`, `context/meta.json`
- Error modes
  - Validation failures: auto-repair where safe; otherwise stop with clear message
  - Overwrite conflicts: respect `overwrite_existing` or prompt (non-interactive flows use defaults)

Edge cases (plan for these)
---------------------------

- Missing mission/standards – proceed with minimal facts; note N/A in `facts.md`
- Large specs – rely on section-level loads; avoid reading full files in one shot
- Extension capability missing – safe skip; core path remains deterministic
- Re-runs – use manifest hashes to skip unchanged files and reduce tokens

How to make changes safely
--------------------------

1. Identify the touchpoint (template, core step, or extension)
2. Update or add the smallest artifact (e.g., a template or extension step)
3. Validate with existing validators (spec/tasks validators)
4. Smoke-test: run or simulate the flow with `debug_extensions: true` and confirm section hashes update
5. Keep changes budget-aware: prefer P1/P2 context; avoid broad file reads

Testing & debugging
-------------------

- Discovery report: set `debug_extensions: true` to emit and save the merged step order and load decisions
- Validators: ensure section order/counts; run immediately after writes
- Metrics (optional): track token estimates per step to verify improvements

Related docs
------------

- Quickstart: ./quickstart.md
- Configuration: ./configuration.md
- Extensions Quickstart: ./extensions-quickstart.md
- Create-spec steps: ./create-spec-steps.md
- Jira extension: ./jira-extension.md

Customization recipes (step-by-step)
------------------------------------

1) Add a new extension step to create-spec

- Create `@~/.agent-os/instructions/extensions/create-spec/my-vendor.md` with:

```markdown
---
description: My Vendor integration for create-spec
targets: ["create-spec"]
version: 1.0
vendor: my-vendor
---

<variables>
  <my_vendor_enabled>false</my_vendor_enabled>
</variables>

<step number="1.2" subagent="context-fetcher" name="my_vendor_init">
## Step 1.2 (Extension): My Vendor init
<gate>
  RUN ONLY IF: [my_vendor_enabled] == true
</gate>
<actions>
  1. FETCH inputs from My Vendor
  2. MAP to core inputs (main_idea, initial_user_stories, in_scope, expected_deliverables)
</actions>
</step>
```

- Enable it by setting `my_vendor_enabled: true` in your create-spec input block.
- Tip: Use `debug_extensions: true` to view the Discovery Report and confirm the merged order.

2) Introduce a new template and use it in a step

- Add `templates/my-checklist.md` with variables documented at the top.
- Reference it from a core or extension step using `<template_reference>` and keep variables minimal:

```markdown
<template_reference>
  TEMPLATE: @templates/my-checklist.md
  VARIABLES: [SPEC_NAME, OWNER]
  POPULATE: Fill from context and defaults; prompt only if missing
  BUDGET: P1/P2 only
</template_reference>
```

3) Adjust context budgets

- Keep P1 under ~100 tokens; shift non-critical reads to P2.
- If you must exceed, explicitly justify in the step and add a note to the manifest for traceability.

4) Add section-level tracking for a new long section

- When adding long sections to `spec.md` or sub-specs, update the manifest updater to register the new section key and token estimate. Favor fine-grained sections (e.g., `overview`, `deliverables`, `api:endpoints`).

LLM-ready snippets
------------------

Selective section read (pseudocode)

```text
IF manifest.spec.sections["overview"].hash == previous_hash THEN SKIP
ELSE READ only lines manifest.spec.sections["overview"].lines
```

Budget gate example

```json
{
  "context_budget": {
    "total_available": 4000,
    "essential_usage": 120,
    "conditional_usage": 580,
    "remaining": 3300
  }
}
```

Extension discovery (front-matter only)

```text
FOR each file in extensions:
  READ front matter only
  IF requires contains unsupported capability -> SKIP
  ELSE cache metadata (TTL=1h) and include
```

Section keys reference
----------------------

- spec.md core: `overview`, `user_stories`, `scope`, `deliverables`, `technical_details`
- spec.md optional: `api_spec`, `database_changes`
- api-spec.md (typical): `endpoints`, `models`, `validation`, `errors`
- database-schema.md (typical): `tables`, `migrations`, `constraints`

Change-impact checklist
-----------------------

When you change spec structure or context behavior, update:

- docs/create-spec-steps.md (section order and conditional notes)
- docs/quickstart.md (expected sections)
- docs/smoke-tests.md (verification lists)
- docs/glossary.md (definitions)
- docs/create-spec-usage.md (determinism & validation)
- docs/architecture.md (this file) if adding new mechanisms

Cross-references
----------------

- Implementation details and metrics: ../llm-context-optimization-implementation.md
