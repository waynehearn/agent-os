---
title: Jira Extension Guide
version: 1.0
lastUpdated: 2025-08-15
---

Use this guide to enable and run the Jira-driven create-spec flow via the Atlassian extension.

Overview
--------

The Jira extension lets you:

- Start create-spec with a Jira issue key (auto-maps fields)
- Optionally post the resulting spec.md back to the Jira issue

Requirements
------------

- Spec Agent Kibo instructions at `@~/.agent-os/instructions/`
- Atlassian MCP configured in your editor
- Jira extension file present: `instructions/extensions/create-spec/atlassian-jira.md` (home or project scope)

Enable the extension
--------------------

The extension is already included in this repository at:
`instructions/extensions/create-spec/atlassian-jira.md`

Place it in one of these locations so it can be discovered by the core flow:

- Home scope: `@~/.agent-os/instructions/extensions/create-spec/`
- Project scope: `@.agent-os/instructions/extensions/create-spec/`

Run with Jira inputs
--------------------

Minimal block:

```text
@~/.agent-os/instructions/core/create-spec.md

[jira_inputs]
jira_issue_key: ABC-1234
use_jira_mcp: true
[/jira_inputs]
```

Empty template: all keys
------------------------

Copy/paste this into your Jira ticket and fill in as needed.

```text
@~/.agent-os/instructions/core/create-spec.md

[jira_inputs]
# Jira source
jira_issue_key: ""               # e.g., ABC-1234 (or prefix with jira:)
use_jira_mcp: true               # use Atlassian MCP to fetch and map fields

# Post spec back to Jira (optional)
post_spec_to_jira: false         # set true to comment spec.md to the issue
jira_comment_mode: summary        # summary | diff | full

# Overrides (use if Jira is missing details)
main_idea: ""
initial_user_stories: []
in_scope: []
out_of_scope: []
expected_deliverables: []
tech_constraints: ""

# Conditional sub-spec flags
requires_db_changes: false
requires_api_changes: false

# Determinism / control
spec_name_override: ""           # optional explicit spec name (kebab-case recommended)
overwrite_existing: false        # set true to overwrite any existing files

# Debugging (optional)
debug_extensions: false          # prints/saves an Extensions Discovery Report
[/jira_inputs]
```

Concrete example: ASP.NET Core Web API new endpoint
---------------------------------------------------

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

Post spec back to Jira (optional)
---------------------------------

```text
@~/.agent-os/instructions/core/create-spec.md

[jira_inputs]
jira_issue_key: ABC-1234
use_jira_mcp: true
post_spec_to_jira: true
jira_comment_mode: summary  # summary | diff | full
[/jira_inputs]
```

Debug extension discovery (optional)
------------------------------------

Add this to your input block to print and save a discovery report to `@[spec_folder_path]/debug/extensions-discovery.txt`:

```text
@~/.agent-os/instructions/core/create-spec.md

[jira_inputs]
jira_issue_key: ABC-1234
use_jira_mcp: true
debug_extensions: true
[/jira_inputs]
```

Notes
-----

- The extension dedupes Jira comments using a sha256 footer to avoid duplicates on re-runs.
- Keys accept formats like `ABC-1234` or `jira:ABC-1234` (prefix is stripped).
- If Jira lacks good fields, supply overrides in the same block.
- For non-Jira quickstarts, use the manual `[spec_inputs]` path instead. See Quickstart.


