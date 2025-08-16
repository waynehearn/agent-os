---
title: Extensions Quickstart
version: 1.0
lastUpdated: 2025-08-14
---

<!-- markdownlint-disable MD033 MD032 MD007 MD022 MD023 MD041 -->

## Extend core flows in minutes

Agent‑OS supports optional instruction “extensions” so you can add project‑specific behavior to core flows (like create‑spec) without forking or editing the core files. If no extensions are present, core behavior is unchanged.

### TL;DR

1) Create a file under one of these folders:

- Home scope: `@~/.agent-os/instructions/extensions/create-spec/`
- Project scope: `@.agent-os/instructions/extensions/create-spec/`

1) Add front matter and a step using decimal numbering:

```markdown
---
description: Example integration for create-spec
targets: ["create-spec"]
version: 1.0
vendor: acme
---

<variables>
  <acme_flag>false</acme_flag>
</variables>

<step number="1.1" subagent="context-fetcher" name="acme_initiation">
## Step 1.1 (Extension): ACME initiation (optional)
<gate>
  RUN ONLY IF: [acme_flag] == true
</gate>
<actions>
  1. FETCH/derive inputs from your system
  2. MAP them to core inputs: main_idea, initial_user_stories, in_scope, expected_deliverables
</actions>
</step>
```

1) Enable it in your instruction block by setting `acme_flag: true` (or your own variable) and run create‑spec.

### Conventions you need to know

- Discovery order:
  1. `@~/.agent-os/instructions/extensions/create-spec/**/*.md`
  2. `@.agent-os/instructions/extensions/create-spec/**/*.md`
- Front matter must include `targets: ["create-spec"]` to be picked up by the create‑spec flow.
- Optional: add `requires: ["capability"]` to declare dependencies (e.g., `mcp:atlassian`). The system reads only the front matter to evaluate `requires` and skips the file entirely when the capability isn’t available.
- Steps are merged by numeric step number (use decimals like 1.1, 6.2). If a collision occurs, the core step runs first, then the extension step.
- Use clear, short variable names; add a vendor prefix only if you expect collisions (e.g., `acme_flag`).
- Core determinism/validation rules still apply. Extensions must be optional and safe to skip.

### Examples

- Minimal skeleton: see above snippet
- Complete reference: `instructions/extensions/README.md`
- Real example (Jira): `instructions/extensions/create-spec/atlassian-jira.md`

### Test checklist

- Step numbers land where you expect (1.1 after core Step 1, 6.2 after Step 6/6.1)
- Your extension flags default to false; enabling them triggers your steps
- Core outputs (spec.md, tasks.md) still satisfy structure and count constraints

### Debugging extension discovery

- Set `debug_extensions: true` in your create‑spec input block to print an "Extensions Discovery Report" before Step 1.
- The report shows:
  - Detected capabilities (when your runtime exposes them)
  - Each candidate file, whether it LOADED or was SKIPPED, and why (e.g., `requires mcp:atlassian not available`).
  - Totals loaded vs skipped.
  - A copy is saved to `@[spec_folder_path]/debug/extensions-discovery.txt` for later review.
  - A "Merged step order (preview)" showing the final step sequence (core and extensions) with source tags like `[core]` or `[ext:atlassian]`.
