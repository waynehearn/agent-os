---
title: Create Spec – Usage and Details
version: 1.0
lastUpdated: 2025-08-16
---
Create a feature spec and tasks from roadmap, Jira, or manual inputs.

> Using Jira (extension): For Jira‑driven specs, use the Jira Extension Guide: [docs/jira-extension.md](./jira-extension.md). This page documents the manual `[spec_inputs]` path; Jira keys are defined in the extension guide.

## Where it fits

- New project: run plan‑product first. Existing project: optionally run analyze‑product to align docs with code, then use create‑spec → execute‑tasks.
- Required to kick off implementation for a new feature. Benefits: consistent spec structure, normalized naming, validated tasks, and lite‑first context used by execution flows.

## Basic usage

Manual (standard mode):

```text
@~/.agent-os/instructions/core/create-spec.md

[spec_inputs]
main_idea: >
  [1–2 sentence goal/intent for this feature]

initial_user_stories:
  - title: [Story title]
    story: As a [USER_TYPE], I want to [ACTION], so that [BENEFIT].
    details: [1–3 sentences on workflow & problem solved]

in_scope:
  - [Clear, concrete item 1]
  - [Item 2]

expected_deliverables:
  - [Externally verifiable outcome 1]
  - [Outcome 2]

requires_api_changes: false
requires_db_changes: false
overwrite_existing: false
[/spec_inputs]
```

Other entry points:

- Roadmap “what’s next?”

```text
@~/.agent-os/instructions/core/create-spec.md

[whats_next]
trigger: "what's next?"
[/whats_next]
```

- Jira (via extension): see the Jira Extension Guide for inputs and examples: [docs/jira-extension.md](./jira-extension.md)

## What it does (steps)

From `instructions/core/create-spec.md`:

1. Validate inputs and normalize spec name (kebab‑case, ≤5 words).
2. Choose mode (standard/express/investigate) and set guardrails accordingly.
3. Create `spec.md` with required sections in strict order; enforce counts.
4. Create `spec-lite.md` (condensed) and write lite context under `context/`.
5. Create sub‑specs under `sub-specs/` in standard mode (technical, api, db; conditional).
6. Generate `tasks.md` from the spec; run tasks‑validator for structure/numbering.
7. Write/refresh `context/manifest.json` and `context/meta.json` (hashes/flags).
8. Run post‑write validation/repairs and summarize outputs.
9. Extensions (optional): e.g., Jira comment sync with dedupe by content hash.

## Try it (bash)

These optional bash commands help with spec context and hashes. Use Git Bash on Windows, WSL, or any Unix shell.

Hash sections for a golden example (useful for selective reloads):

```bash
bash tools/section-hash.sh "examples/golden"
```

Verify jq and optionally check a spec’s manifest exists:

```bash
bash tools/verify-jq.sh
```

Backfill lite-first context for an existing spec folder (if you migrated old specs):

```bash
bash tools/backfill-context.sh
```

## Artifacts produced

Creates a folder: `@.agent-os/specs/YYYY-MM-DD-<spec-name>/` with:

- `spec.md`, `spec-lite.md`, `tasks.md`
- `sub-specs/technical-spec.md` (+ `api-spec.md`, `database-schema.md` when applicable)
- `context/facts.md`, `context/manifest.json`, `context/meta.json`

All paths are referred to as `[spec_folder_path]` in downstream flows.

## Inputs and flags

- Required content: `main_idea`, `initial_user_stories` (1–3), `in_scope` (1–5), `expected_deliverables` (1–3)
- Optional: `tech_constraints`, `out_of_scope`, `spec_name_override`, `overwrite_existing`
- Mode: `mode = standard | express | investigate` (default: standard)
- Non‑interactive: `non_interactive: true` to auto‑approve deterministic defaults
- Flags that shape tasks/execution: `requires_api_changes`, `requires_db_changes`
- Jira (extension): `jira_issue_key`, `use_jira_mcp`, `jira_comment_mode = full|summary|diff`
- Discovery/debug: `debug_extensions: true` to emit extension loader report

Authoritative schema: `docs/schemas/spec-input.schema.json`.

## Extensions discovery (debug)

Enable a concise Extensions Discovery Report before Step 1 to see which extensions are considered and why they load/skip.

- Turn on via either:
  - In inputs: `debug_extensions: true`
  - Or env: `DEBUG_EXTENSIONS=1`
- Optional env variables:
  - `RUNTIME_CAPABILITIES` — comma-separated capabilities (e.g., `mcp:atlassian`) used to satisfy `requires` in extension front matter.
  - `EXTENSIONS_ENABLED` — set to `false`/`0` to skip discovery entirely.
  - `EXTENSION_SCOPE` — `home|project|repo|all|none` to control lookup roots.
  - `EXTENSION_EXTRA_ROOTS` — comma-separated absolute paths for additional roots.
- Output: report saved to `@[spec_folder_path]/debug/extensions-discovery.txt` containing:
  - LOADED/SKIPPED lines with reasons (e.g., `requires mcp:atlassian not available`).
  - Summary counts loaded vs skipped.
  - A "Merged step order (preview)" showing core and extension steps in execution order.
- Efficiency: discovery uses front‑matter‑only scanning; bodies are not read unless loaded.

## Modes: Express vs Standard

Express focuses on speed; Standard maximizes validation and traceability.

- Express skips extended validation/cross‑refs and does not create sub‑specs.
- Standard performs deeper checks and creates sub‑specs when API/DB are involved.
- Both modes always validate section order/counts and generate lite context.
- Tasks still include API/DB work when flags are set, even without sub‑specs (execution flows use `meta.json`).

When to use Express: small UI changes, simple endpoints following a pattern, instrumentation/logging. Prefer Standard for cross‑cutting work, new dependencies, or compliance/risk.

## Extensibility and customization

- Extension loader (create‑spec only):
  - Jira integration: see `docs/jira-extension.md` and the canonical key reference.
  - Task Organization Hints: ordering/grouping guidance; does not add/remove tasks.
- Re‑sync to Jira: re‑run with the same `jira_issue_key` and your `jira_comment_mode`; dedupes by content hash.
Re‑sync to Jira: re‑run with the same `jira_issue_key` and your `jira_comment_mode`; dedupes by content hash (see [Jira Extension Guide](./jira-extension.md)).
- Standards influence phrasing/structure; keep `standards/` up‑to‑date.

## Examples

Manual – Standard:

```text
@~/.agent-os/instructions/core/create-spec.md

[spec_inputs]
main_idea: >
  Allow editing a location via PATCH /api/v1/locations/{id} with optimistic concurrency.

initial_user_stories:
  - title: Edit location name
    story: As an admin, I want to update a location name so that data stays accurate.
    details: Use ETag for concurrency; return 412 on mismatch.

in_scope:
  - Update endpoint and validation
  - Concurrency via ETag

expected_deliverables:
  - PATCH updates succeed with matching ETag; 412 otherwise

requires_api_changes: true
requires_db_changes: false
[/spec_inputs]
```

Manual – Express:

```text
@~/.agent-os/instructions/core/create-spec.md

[spec_inputs]
mode: express
non_interactive: true
main_idea: >
  Add export‑to‑CSV to Reports page using existing filters.

initial_user_stories:
  - title: Export filtered report
    story: As an analyst, I want to export the filtered report to CSV so I can analyze offline.
    details: Respect date/status filters; max 10k rows.

in_scope:
  - Add Export CSV button; reuse query

expected_deliverables:
  - CSV download matches on‑screen filters

requires_api_changes: false
requires_db_changes: false
[/spec_inputs]
```

Jira‑driven – Express with API work:

See Jira-driven examples in the Jira Extension Guide: [docs/jira-extension.md](./jira-extension.md)

## Non‑interactive mode

When `non_interactive: true`:

- Equivalent to auto‑approve; confirmations are skipped and logged with "DEFAULT:" prefix.
- Validation errors stop the run (no interactive retries).

## Investigation mode

Investigation supports bug/performance/security/architecture/feasibility work. It outputs reports and can generate Jira tickets and ready‑to‑use spec templates.

See “Investigation Mode” details below for types, outputs, and an end‑to‑end example flow.

## Tips

- Keep `main_idea` brief; it drives normalized naming when no override is set.
- Deliverables must be externally verifiable.
- For execution details (hybrid API/DB consults, selective reads), see `docs/execute-tasks-usage.md`.

## Reference

### Spec input fields (authoritative list)

JSON Schema: [schemas/spec-input.schema.json](./schemas/spec-input.schema.json)

Note: This table documents fields for the manual `[spec_inputs]` path. Jira extension keys (e.g., `jira_issue_key`, `use_jira_mcp`, `jira_comment_mode`) are defined canonically in [docs/jira-extension.md](./jira-extension.md).

| Field | Type | Required | Constraints | Description |
|-------|------|----------|-------------|-------------|
| `main_idea` | string | Yes | 1-2 sentences | Core goal/intent for this feature |
| `initial_user_stories` | array | Yes | 1-5 stories | User stories with title, story, details |
| `in_scope` | array | Yes | 1-8 items | Clear, concrete scope items |
| `out_of_scope` | array | No | 0-5 items | Explicit exclusions |
| `expected_deliverables` | array | Yes | 1-5 items | Externally verifiable outcomes |
| `tech_constraints` | string | No | - | Framework/version/performance limits |
| `requires_db_changes` | boolean | No | - | Database schema changes needed |
| `requires_api_changes` | boolean | No | - | API contract changes needed |
| `spec_name_override` | string | No | - | Custom spec name (auto-generated if empty) |
| `overwrite_existing` | boolean | No | - | Overwrite existing spec if exists |
| `mode` | string | No | express\|standard\|investigate | Workflow mode (default: standard) |
| `non_interactive` | boolean | No | default: false | Alias for --auto-approve, enables deterministic defaults |
| `investigation_type` | string | No (required if mode=investigate) | bug\|performance\|security\|architecture\|feasibility | Type of investigation |
| `symptoms` | array | No | 1-8 items | Observed issues, questions, or areas of concern |
| `working_hypothesis` | string | No | 1-2 sentences | Optional starting theory or direction |
| `affected_systems` | array | No | 0-5 items | Components or areas that might be involved |
| `generate_tickets` | boolean | No | default: false | Auto-generate Jira tickets from findings |
| `ticket_project_key` | string | No (required if generate_tickets=true) | - | Jira project key for ticket creation |
| `ticket_priority_default` | string | No | High\|Medium\|Low | Default priority for generated tickets (default: Medium) |
| `ticket_labels` | array | No | 0-5 items | Standard labels to apply to all tickets |

### Required section order

spec.md

1. Overview
2. User Stories
3. Scope
4. Deliverables
5. Technical Details
6. API Specification (if applicable)
7. Database Changes (if applicable)

tasks.md

1. Task Summary
2. Implementation Tasks
3. Testing Tasks
4. Documentation Tasks
5. Deployment Tasks

### Manifest schema

```json
{
  "spec_name": "string - normalized feature name",
  "created_date": "string - ISO 8601 timestamp",
  "last_modified": "string - ISO 8601 timestamp",
  "checksum": "string - SHA256 hash of spec.md content",
  "tasks_checksum": "string - SHA256 hash of tasks.md content",
  "mode": "string - express|standard",
  "validation_status": "string - passed|failed|pending",
  "dependencies": ["array of string - prerequisite specs"],
  "extensions_used": ["array of string - extension names applied"]
}
```

See also:

- Manifest details: [manifest-spec.md](./manifest-spec.md)
- JSON Schema: [schemas/manifest.schema.json](./schemas/manifest.schema.json)

Hashing rules:

- Algorithm: SHA256
- Input: File content with normalized line endings (LF only)
- Encoding: UTF‑8
- Update: Hash regenerated on content change

## Next steps

After the spec is approved, move to implementation: see `docs/execute-tasks-usage.md`.

## Investigation Mode (detailed)

The following section provides the detailed investigation guidance preserved from earlier versions for completeness.

### Overview

Investigation mode supports bug diagnosis, performance analysis, security audits, and exploratory development work. It creates structured investigation reports and can automatically generate actionable Jira tickets for implementation.

### When to Use Investigation Mode

- Bug Diagnosis, Performance Analysis, Security Audits, Architecture Research, Feasibility Studies

### Investigation Types

#### Bug Investigation

```yaml
mode: investigate
investigation_type: bug
symptoms:
  - "Login endpoint returns 500 errors intermittently"
  - "Error rate increases during peak hours"
working_hypothesis: "Database connection pool exhaustion under load"
expected_deliverables:
  - type: "finding"
    outcome: "Root cause identified with reproduction method"
  - type: "tickets"
    outcome: "3-5 actionable Jira tickets created for fixes"
```

#### Performance Investigation

```yaml
mode: investigate
investigation_type: performance
symptoms:
  - "User dashboard loads in 8+ seconds"
  - "Database queries timing out during peak hours"
affected_systems: ["web-frontend", "user-service", "postgres-db"]
generate_tickets: true
ticket_project_key: "PERF"
```

### Investigation Outputs

- `investigation-report.md`, `findings-summary.md`, `action-items.md`
- `jira-tickets.yaml` (if enabled), `implementation-specs.yaml`

### Ticket Generation

Categories: Immediate Fixes, Improvement Opportunities, Technical Debt, New Features

Each ticket includes a clear title/description, acceptance criteria, priority, links back to the report, labels/metadata, and ready‑to‑use create‑spec inputs where relevant.

### Investigation → Implementation Flow

```bash
# 1. Run investigation
claude create-spec mode=investigate \
  investigation_type=performance \
  symptoms="Dashboard loads slowly" \
  generate_tickets=true \
  ticket_project_key="PERF"

# 2. Review tickets in Jira, prioritize work

# 3. Implement high-priority items
# Use Jira-driven inputs: see Jira Extension Guide for the `[jira_inputs]` block
# docs/jira-extension.md
```

### Example Investigation Scenarios

See examples above for performance/security.

## See also

- Quickstart: [QuickStart Guide.md](QuickStart%20Guide.md)
- Troubleshooting: [troubleshooting.md](./troubleshooting.md)
- Glossary: [glossary.md](./glossary.md)
- Configuration: [configuration.md](./configuration.md)
- Installation: [installation.md](./installation.md)
- Execute tasks: [execute-tasks-usage.md](./execute-tasks-usage.md)

## Runtime: Extension step execution

When extensions are enabled, loaded extension steps execute at numeric boundaries during the run:

- Steps with numbers < 1 run after the spec folder is created and before Step 1 completes.
- Steps 1.x run after the product context discovery sub-step.
- Steps 2.x, 3.x, 4.x, 5.x each run after their respective core steps.
- Steps 6.x, 7.x, 8.x run after the respective late steps.
- Any remaining steps (e.g., > 8.999) run after the Conclusion.

Notes

- Step numbers come from `<step number="X[.Y]" name="...">` tags in core and extension instruction files.
- Execution currently logs a placeholder per step; dispatch to specific subagents can be added later using extension metadata.
- Discovery and execution honor `EXTENSION_SCOPE`, `RUNTIME_CAPABILITIES`, and `EXTENSION_EXTRA_ROOTS`.
