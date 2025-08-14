---
title: Spec Agent Kibo – Quickstart
version: 1.0
lastUpdated: 2025-08-14
---

Start here if you’re new. In ~10 minutes you’ll create a spec from a Jira issue, verify outputs, and run targeted tasks.

What is Spec Agent Kibo?
------------------

Spec Agent Kibo is a system for spec‑driven agentic development. It gives AI coding agents structured workflows aligned to your standards, stack, and codebase context so they ship quality code on the first try—not the fifth.

Works with
----------

- Claude Code, Cursor, or other AI coding tools
- New products or established codebases
- Big features or small fixes
- Any language or framework

Prerequisites
-------------

- Spec Agent Kibo instructions at `@~/.agent-os/instructions/`
- Optional: Atlassian MCP configured (for Jira-driven flow)

Step 1 — Create spec from Jira example
--------------------------------------

Copy and run the Jira-driven example below (adjust Jira key, date, and NuGet package as needed).

```text
@~/.agent-os/instructions/core/create-spec.md

[jira_inputs]
jira_issue_key: API-482
use_jira_mcp: true

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

Step 2 — Verify outputs
-----------------------

- Folder exists: `@.agent-os/specs/YYYY-MM-DD-add-events-post-endpoint/`
- Files exist:
  - `spec.md`
  - `spec-lite.md`
  - `sub-specs/technical-spec.md`
  - `sub-specs/database-schema.md` (DB required)
  - `sub-specs/api-spec.md` (API required)
  - `tasks.md`
- `spec.md` sections in strict order: Overview, User Stories, Spec Scope, Out of Scope, Expected Deliverable

Step 3 — Execute only API and DB tasks
-------------------------------------

Open `[spec_folder_path]/tasks.md` to confirm numbers, then run only those parent tasks:

```text
@~/.agent-os/instructions/core/execute-tasks.md

[execution_context]
spec_folder_path: @.agent-os/specs/YYYY-MM-DD-add-events-post-endpoint
specific_tasks:
  - 1   # API endpoint task (adjust)
  - 4   # DB table/migration task (adjust)
[/execution_context]
```

Step 4 — Validate (optional but recommended)
-------------------------------------------

- Spec validator

```text
@~/.agent-os/instructions/core/spec-validator.md

[spec_validation]
SPEC_PATH: @.agent-os/specs/YYYY-MM-DD-add-events-post-endpoint/spec.md
[/spec_validation]
```

- Tasks validator

```text
@~/.agent-os/instructions/core/tasks-validator.md

[tasks_validation]
TASKS_PATH: @.agent-os/specs/YYYY-MM-DD-add-events-post-endpoint/tasks.md
[/tasks_validation]
```

Next steps
----------

- See smoke tests: [smoke-tests.md](./smoke-tests.md)
- Learn modes and options: [create-spec-usage.md](./create-spec-usage.md)
- Troubleshoot: [troubleshooting.md](./troubleshooting.md)
- Glossary: [glossary.md](./glossary.md)
- Configuration: [configuration.md](./configuration.md)
- Installation: [installation.md](./installation.md)

External resources
------------------

- Spec Agent Kibo website (docs, installation, best practices): [buildermethods.com/agent-os](https://buildermethods.com/agent-os)
- Builder Briefing newsletter: [buildermethods.com](https://buildermethods.com)
- YouTube (Brian Casel): [youtube.com/@briancasel](https://youtube.com/@briancasel)
