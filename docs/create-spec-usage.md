---
title: Using create-spec from Claude Code
version: 1.0
lastUpdated: 2025-08-14
---
This guide shows how to run the create-spec flow from Claude Code with three input sources (with optional extensions):

- Roadmap-driven ("what's next?")
- Jira-driven (via Atlassian MCP) – via optional extension
- Manual input (structured template)

It also covers expected outputs, idempotency behavior, and common pitfalls.

Prerequisites
-------------

- Spec Agent Kibo instructions folder is available at `@~/.agent-os/instructions/`
- Standards docs are present in `@.agent-os/standards/`
- Optional: Atlassian MCP configured if you want to pull from Jira (enable by adding the Jira extension file under `@~/.agent-os/instructions/extensions/create-spec/`)

Shell environment
-----------------

- This guide targets editor-driven flows and works the same in Git Bash, bash, and zsh.
- Examples shown are shell-agnostic (they are instruction references, not shell commands).
- Optional completion chime in bash-compatible shells:
  - printf '\a'  # emits BEL (audible bell if enabled)
- Shell: examples assume a bash-like shell (git-bash on Windows, WSL, macOS Terminal, or Linux)

Outputs
-------

When successful, the flow creates a spec folder at:

- `@.agent-os/specs/YYYY-MM-DD-<spec-name>/`

With files:

- `spec.md`
- `spec-lite.md`
- `sub-specs/technical-spec.md`
- `sub-specs/database-schema.md` (conditional)
- `sub-specs/api-spec.md` (conditional)
- `tasks.md`

Lite-first context artifacts (new)
---------------------------------

- `context/facts.md`
  - Summarizes mission/spec facts for quick AI context. If no mission docs exist, it will include: `Mission (lite): N/A`.
- `context/manifest.json`
  - Tracks sha256 + lastModified for key files. The execution flows skip re-reading files when hashes match.
  - Example (truncated):
    {
      "files": {
        "spec.md": {"sha256": "…", "lastModified": "2025-08-14T12:00:00Z"},
        "spec-lite.md": {"sha256": "…", "lastModified": "2025-08-14T12:00:05Z"}
      }
    }
- `context/meta.json`
  - Tiny counts/flags (e.g., section counts) for quick gating.
  - Example:
    {"spec": {"sections": 5}, "tasks": {"parents": 4}}

All paths are normalized using `[spec_folder_path]` in the instructions.

Roadmap-driven ("what's next?")
-------------------------------

Use this when you want the agent to pick the next uncompleted roadmap item.

```text
@~/.agent-os/instructions/core/create-spec.md

[whats_next]
trigger: "what's next?"
[/whats_next]
```

What happens:

- The flow reads `@.agent-os/product/roadmap.md`
- Suggests the next uncompleted item and asks for approval
- Proceeds with spec creation after confirmation

Jira-driven (via Atlassian MCP, via extension)
--------------------------

Use this when you have a Jira issue key and an Atlassian MCP service configured, plus the Jira extension installed.

```text
@~/.agent-os/instructions/core/create-spec.md

[jira_inputs]
ext_jira_issue_key: ABC-1234
ext_use_jira_mcp: true
# Optional overrides if Jira fields are missing
ext_post_spec_to_jira: true
ext_jira_comment_mode: summary
main_idea: ""
initial_user_stories: []
in_scope: []
out_of_scope: []
expected_deliverables: []
tech_constraints: ""
requires_db_changes: false
requires_api_changes: false
spec_name_override: ""
overwrite_existing: false
[/jira_inputs]
```

What happens:

- The flow fetches Jira fields (summary, description, status, labels/components, acceptance criteria, etc.)
- Maps them to the required inputs and prompts for any missing items
- Asks for confirmation before proceeding
- Proceeds even if no `mission.md` or `mission-lite.md` exists (facts.md will note N/A)
- After `spec.md` is created, the extension posts the spec content back to the Jira issue as a comment (conditional on MCP and valid key)
  - If the spec is too large for Jira, it posts only Overview and Expected Deliverable sections with a repo path reference
  - A footer includes a short hash to avoid duplicate re-posts on re-runs
  - If `ext_jira_comment_mode: summary`, subsequent runs post a concise summary of changes (section deltas, counts, top highlights). If set to `diff`, they post a unified diff instead. Otherwise, they post the full content or an excerpt.

Concrete Jira example: ASP.NET Core Web API new endpoint (with DB table and repo package)
----------------------------------------------------------------------------------------

Use this when you want to add a new POST endpoint to an existing controller in a .NET Core ASP.NET Web API app. The app uses a layered architecture (API layer -> domain handler layer -> repo layer). The endpoint accepts a simple JSON payload, applies domain-level validation rules, and persists to the database via a repository that uses a specific NuGet package. A new table is required.

```text
@~/.agent-os/instructions/core/create-spec.md

[jira_inputs]
ext_jira_issue_key: API-482
ext_use_jira_mcp: true

# Provide overrides if Jira is missing fields
main_idea: >
  Add POST /api/v1/events to existing EventsController to accept a JSON payload and persist it using the domain handler + repository pattern.

initial_user_stories:
  - title: Create Event endpoint
    story: As an integrator, I want to POST a new Event JSON to /api/v1/events so that it is validated and stored for downstream processing.
    details: >
      Payload example: {"type":"purchase","userId":"u-123","occurredAt":"2025-08-14T12:00:00Z","metadata":{"sku":"ABC-123"}}
      The API layer forwards to a domain handler that enforces validation rules, then calls the repository to persist.

in_scope:
  - API: Add POST /api/v1/events to existing EventsController
  - Domain: Implement EventCreateHandler with validation rules
  - Validation rules (domain): type required (non-empty, <= 50 chars); userId required (non-empty); occurredAt required (UTC, not in future); metadata optional (<= 10 KB JSON)
  - Repository: Add IEventRepository + implementation using NuGet package [NuGetPackageId]
  - Database: Create Events table (Id PK GUID, Type NVARCHAR(50), UserId NVARCHAR(100), OccurredAt DATETIMEOFFSET, Metadata NVARCHAR(MAX), CreatedAt DATETIMEOFFSET)
  - Wiring: Register handler and repository in DI; configure package initialization if required
  - Tests: Unit tests for domain validation; integration test for POST endpoint (201 Created) and DB insert

out_of_scope:
  - UI or portal changes
  - Reporting/analytics pipelines
  - Bulk ingestion endpoints

expected_deliverables:
  - POST /api/v1/events returns 201 Created with Location header and persisted record ID
  - Events table exists with migration applied and record persisted end-to-end
  - Domain validation rejects invalid payloads with 400 and problem details

tech_constraints: >
  ASP.NET Core Web API; layered architecture (API -> Domain -> Repo); use specific NuGet package in repo layer: [NuGetPackageId] ([version]). Provide DI registration and any necessary configuration.

requires_db_changes: true
requires_api_changes: true

spec_name_override: "add-events-post-endpoint"
overwrite_existing: false
[/jira_inputs]
```

Jira comment result (example):

```text
Comment on API-482

Spec Requirements Document for add-events-post-endpoint

Repository path: @.agent-os/specs/YYYY-MM-DD-add-events-post-endpoint/spec.md

---
[Spec content or excerpt]

---
Synced by Spec Agent Kibo • key: YYYY-MM-DD-add-events-post-endpoint • sha256: <hash>
```

Manual input (structured)
-------------------------

Use this when you want to specify all inputs explicitly.

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

out_of_scope:
  - [Optional exclusion]

expected_deliverables:
  - [Browser-testable outcome 1]
  - [Outcome 2]

tech_constraints: >
  [Optional: frameworks, versions, patterns, perf limits]

requires_db_changes: false
requires_api_changes: false

spec_name_override: ""
overwrite_existing: false
[/spec_inputs]
```

Determinism & Validation
------------------------

- Name normalization: kebab-case, ≤ 5 words
- Required sections in `spec.md` in strict order: Overview, User Stories, Spec Scope, Out of Scope, Expected Deliverable
- Counts enforced: User Stories 1–3, Spec Scope 1–5, Expected Deliverables 1–3
- Post-write validation runs and repairs the file if needed
- `tasks.md` is validated and normalized right after creation

Skip-by-hash & selective reads
------------------------------

- During execution, the flows consult `context/manifest.json` to avoid re-loading unchanged files.
- They prefer `spec-lite.md`, `context/facts.md`, and task-scoped snippets over full-document loads.
- Strict do-not-load during execution: `decisions.md` and full `mission.md` (roadmap only when needed).

Idempotency
-----------

- If any target file exists and `overwrite_existing` is false, you will be asked before overwriting
- If you choose not to overwrite, the file is skipped and noted in the summary

Tips & Pitfalls
---------------

- Keep main_idea to 1–2 sentences; it drives the spec name if you don’t override
- Ensure deliverables are browser-testable outcomes
- For Jira keys, formats like `ABC-1234` are accepted; an optional `jira:` prefix is also allowed
- If the technical spec isn’t needed for a simple change, it’s still created but can be minimal; DB/API sub-specs are conditional

Next steps
----------

After the spec is approved (Step 11), use the execute-tasks command to start implementation.

Run next uncompleted task:

```text
@~/.agent-os/instructions/core/execute-tasks.md

[execution_context]
spec_folder_path: @.agent-os/specs/YYYY-MM-DD-spec-name
[/execution_context]
```

See also
--------

- Simple smoke tests: [smoke-tests.md](./smoke-tests.md)
- Quickstart: [quickstart.md](./quickstart.md)
- Troubleshooting: [troubleshooting.md](./troubleshooting.md)
- Glossary: [glossary.md](./glossary.md)
- Configuration: [configuration.md](./configuration.md)
- Installation: [installation.md](./installation.md)

Manual Jira re-sync (optional, via extension)
------------------------------

Re-sync is manual by design. To update the Jira comment after editing `spec.md`, re-run Step 6.2 (extension) of `create-spec` with the same `ext_jira_issue_key` and your preferred `ext_jira_comment_mode`. The extension will dedupe by hash and only post a new comment when content changes.

Run only API and DB tasks for the new endpoint spec
---------------------------------------------------

Use this to run just the parent tasks that implement the API endpoint and database table for the spec created above. Adjust task numbers to match your generated `[spec_folder_path]/tasks.md`.

```text
@~/.agent-os/instructions/core/execute-tasks.md

[execution_context]
spec_folder_path: @.agent-os/specs/YYYY-MM-DD-add-events-post-endpoint
specific_tasks:
  - 1   # API: POST /api/v1/events (adjust to match tasks.md)
  - 4   # Database: Create Events table migration (adjust)
[/execution_context]
```

Optional: run only a targeted subtask (e.g., controller action route wiring) and stop after tests:

```text
@~/.agent-os/instructions/core/execute-tasks.md

[execution_context]
spec_folder_path: @.agent-os/specs/YYYY-MM-DD-add-events-post-endpoint
specific_tasks:
  - 1
execution_notes: >
  Execute only subtask 1.1 (controller action + route) and stop after verifying tests for that subtask.
[/execution_context]
```

Helper scripts (optional)
-------------------------

- Update manifest hashes/mtime after edits:
  - `tools/update-manifest.sh [spec_folder_path]`
- Backfill lite-first context for existing specs:
  - `tools/backfill-context.sh`
- Verify jq and optionally check a spec’s manifest exists:
  - `tools/verify-jq.sh [spec_folder_path]`
