# Plan: `create-spec` Bash Script Implementation

This document tracks the progress of creating a set of bash scripts to replicate the `create-spec` command locally.

## Context Summary (as of August 16, 2025)

- Workspace: agent-os (branch: jira)
- Goal: Replicate the Claude Code `create-spec` workflow using bash scripts for use in VS Code and other environments.
- Scripts created:
  - `tools/create-spec.sh` (orchestrator, initial version)
  - `tools/spec-name-normalizer.sh` (implemented: deterministic, kebab-case, ≤5 words)
  - `tools/discover-product-context.sh` (placeholder, implementation in progress)
  - `tools/spec-validator.sh` (placeholder)
- Next step: Implement logic for `discover-product-context.sh` to find key context files and output as JSON.

## Phase 1: Scaffolding and Core Logic

| Task ID | Description | Status | File(s) | Notes |
|---|---|---|---|---|
| 1 | Create Tracking Document | ✅ Done | `docs/create-spec-script-plan.md` | This document. |
| 2 | Create Orchestrator Script | ✅ Done | `tools/create-spec.sh` | Initial version created. Will need refinement. |
| 3 | Create `spec-name-normalizer.sh` | ✅ Done | `tools/spec-name-normalizer.sh` | Implemented normalization logic. |
| 4 | Create `discover-product-context.sh` | ✅ Done | `tools/discover-product-context.sh` | Placeholder created, logic in progress. |
| 5 | Create `spec-validator.sh` | ✅ Done | `tools/spec-validator.sh` | Placeholder created. |

## Phase 2: Implementation and Testing

| Task ID | Description | Status | File(s) | Notes |
|---|---|---|---|---|
| 6 | Implement `spec-name-normalizer.sh` | ✅ Done | `tools/spec-name-normalizer.sh` | Logic matches spec normalization rules. |
| 7 | Implement `discover-product-context.sh` | ⬜ In Progress | `tools/discover-product-context.sh` | Will find manifest, README, architecture files and output JSON. |
| 8 | Implement `spec-validator.sh` | ⬜ To Do | `tools/spec-validator.sh` | Add logic for spec validation. |
| 9 | Refine and Test `create-spec.sh` | ⬜ To Do | `tools/create-spec.sh` | Test the end-to-end workflow. |

## Next Steps

- Finish implementation of `discover-product-context.sh`.
- Implement and test `spec-validator.sh`.
- Refine and test the orchestrator script.
