---
title: Spec Agent Kibo – Extensions
version: 1.0
lastUpdated: 2025-08-14
---

<!-- markdownlint-disable MD033 MD032 MD007 MD022 MD023 MD041 -->

## Extensions: extend core flows without changing them

This folder holds optional instruction files that add behavior to core flows (like `create-spec`). Extensions are discovered automatically and merged into execution if present. If no extension files are found, core behavior stays exactly the same.

## Where extension files live

The system searches in this order:

1. `@~/.agent-os/instructions/extensions/<flow>/**/*.md` (user/home scope)
2. `@.agent-os/instructions/extensions/<flow>/**/*.md` (project scope, optional)

For the `create-spec` flow, use:

- `@~/.agent-os/instructions/extensions/create-spec/`
- `@.agent-os/instructions/extensions/create-spec/`

## Contract (front matter and blocks)

- Front matter must include: `targets: ["create-spec"]`
- Optional: `requires: ["capability", ...]` to declare dependencies (e.g., `mcp:atlassian`). The loader reads only front matter to evaluate `requires` and skips the file body when dependencies aren’t available. Results are cached (1‑hour TTL) in the extension registry.
- Allowed content blocks:
  - `<variables>`: define extension-specific variables (use clear, short names; avoid verbose prefixes unless necessary)
  - `<step number="X.Y" subagent="..." name="...">` blocks: add steps into the flow

## Merge rules

- Steps are merged by numeric step number (e.g., 1.1, 6.2). Use decimal positions to avoid conflicts.
- If a collision occurs, the core step runs first, then the extension step.
- Core determinism and validation rules still apply; extensions must not weaken them.
- Extensions are optional and must be safe to skip if missing.

## Naming and safety guidance

- Variables: use clear, namespaced keys to avoid collisions (e.g., `jira_issue_key`).
- Keep side-effects scoped and documented; avoid leaking secrets or absolute local paths.
- Follow the lite-first context policy (prefer `spec-lite.md`, `context/facts.md`, and selective reads).

## Minimal example (create-spec)

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

<step number="6.2" subagent="context-fetcher" name="acme_sync">
## Step 6.2 (Extension): ACME sync (optional)
<condition>
  EXECUTE ONLY IF: [acme_flag] == true
</condition>
<actions>
  1. READ @[spec_folder_path]/spec.md
  2. POST/SYNC to your system with dedupe by content hash
</actions>
</step>
```

## Example: Atlassian/Jira extension

- See `create-spec/atlassian-jira.md` for a complete example that:
  - Enables Jira-driven initiation (maps Jira fields to spec inputs)
  - Posts `spec.md` back to the Jira issue with summary/diff/full modes, deduped by hash
  - Uses variables: `jira_issue_key`, `use_jira_mcp`, `post_spec_to_jira`, `jira_comment_mode`

## Testing tips

- Start with extension flags defaulting to `false`; enable them in your instruction block.
- Run a dry pass: confirm your step numbers insert at the right places (1.1 after core Step 1, 6.2 after 6/6.1, etc.).
- Validate that core file outputs still meet structure and count constraints.

## Troubleshooting

- If your steps don’t run, confirm the file path and that front matter includes `targets: ["create-spec"]`.
- Check `docs/troubleshooting.md` and `docs/configuration.md` for environment/setup details.
