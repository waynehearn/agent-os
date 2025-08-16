---
title: Jira Extension Guide
version: 1.0
lastUpdated: 2025-08-15
---

Use this guide to enable and run the Jira-driven create-spec flow via the Atlassian extension.

## Canonical Jira Key Reference

| Key Name | Description | Example | Required |
|----------|-------------|---------|----------|
| `jira_issue_key` | Jira issue identifier | "ABC-1234", "jira:PROD-123" | Yes |
| `use_jira_mcp` | Enable Atlassian MCP integration | true, false | No (default: false) |
| `post_spec_to_jira` | Post spec back to Jira issue | true, false | No (default: false) |
| `jira_comment_mode` | Format for Jira comments | "summary", "diff", "full" | No (default: "summary") |
| `main_idea` | Core goal/intent override | "Add user logout button" | No (from Jira if available) |
| `initial_user_stories` | User stories override | [{"title": "...", "story": "...", "details": "..."}] | No (from Jira if available) |
| `in_scope` | Scope items override | ["Add logout button", "Session termination"] | No (from Jira if available) |
| `out_of_scope` | Explicit exclusions override | ["Multi-device logout", "Remember me"] | No |
| `expected_deliverables` | Acceptance outcomes override | ["User can click logout", "Session invalidated"] | No (from Jira if available) |
| `tech_constraints` | Technical limitations override | "ASP.NET Core 9, PostgreSQL 17" | No |
| `requires_db_changes` | Database changes flag | true, false | No (default: false) |
| `requires_api_changes` | API changes flag | true, false | No (default: false) |
| `spec_name_override` | Custom spec name | "user-logout-feature" | No (auto-generated if empty) |
| `overwrite_existing` | Overwrite existing spec | true, false | No (default: false) |
| `debug_extensions` | Enable extension debugging | true, false | No (default: false) |

**This is the single source of truth for all Jira keys. Reference this table from other documentation.**

Overview
--------

The Jira extension lets you:

- Start create-spec with a Jira issue key (auto-maps fields)
- Optionally post the resulting spec.md back to the Jira issue
- Remain context-efficient: the loader uses front-matter-only extension discovery and section-aware manifests to minimize tokens

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

Text and formatting inside [jira_inputs]
----------------------------------------

You can use multi-line text, Markdown formatting, and special characters in values. Treat the block like YAML:

- Multi-line text: use YAML block scalars
  - ">" (folded) turns newlines into spaces (good for paragraphs)
  - "|" (literal) preserves newlines (good for Markdown/code/JSON)
- Special characters: allowed; for single-line values containing characters like :, #, [, ], {, }, or leading/trailing spaces, wrap the value in quotes, or prefer a block scalar.
- Lists: use [] for inline arrays or dash-lists for readability; complex items can be objects.
- Indentation: indent block-scalar content by at least two spaces; use spaces, not tabs.

Examples
--------

- Folded paragraph (newlines folded to spaces):

```text
main_idea: >
  Add a POST endpoint to accept JSON and persist via domain handler.
  Validate inputs and return 201 with Location header.
```

- Literal block with Markdown and special characters preserved:

```text
tech_constraints: |
  - ASP.NET Core 9
  - NuGet: "Contoso.Events" >= 1.2.3
  - Env: FOO_BAR="baz:qux"  # inside a literal block this is safe
```

- JSON payload inside a literal block:

```text
details: |
  Example payload:
  {
    "type": "purchase",
    "userId": "u-123",
    "occurredAt": "2025-08-14T12:00:00Z",
    "metadata": {"sku": "ABC-123"}
  }
```

- Arrays (strings and structured items):

```text
expected_deliverables:
  - "**API** returns 201 Created with Location header"
  - "DB row persisted; query by ID returns the record"

initial_user_stories:
  - title: Create Event endpoint
    story: As an integrator, I want to POST an Event so it’s validated and stored.
    details: >
      Validate type, userId, and occurredAt; reject future timestamps.
```

Lists vs multi-line strings (in_scope/out_of_scope)
--------------------------------------------------

Why brackets? `in_scope` and `out_of_scope` are lists (arrays). The `[]` you see is YAML flow style for arrays. You can also write them in block style with dashes (`-`).

How they differ from other multi-line properties: fields like `main_idea` or `tech_constraints` are single strings (scalars). They can span multiple lines using YAML block scalars (`>` folded or `|` literal), but they remain one value, not a list of values.

Use lists for:

- `in_scope` (1–5 items)
- `out_of_scope` (0+ items)
- `initial_user_stories` (1–3)
- `expected_deliverables` (1–3)

Use strings (possibly multi-line) for:

- `main_idea`
- `tech_constraints`

Examples

- Empty vs filled lists (flow style):

```text
in_scope: []
in_scope: ["API: Add endpoint", "DB: Create table"]
```

- Preferred, readable block style lists:

```text
in_scope:
  - API: Add POST /api/v1/events
  - Domain: Implement EventCreateHandler
  - Tests: Unit tests for validation
```

- Multi-line list items (use | or > inside each item):

```text
in_scope:
  - |
    API: Add POST /api/v1/events
    - Validate payload
    - Return 201 with Location header
  - >
    Domain: Implement EventCreateHandler; enforce rules and call repository.
```

- Structured items (objects) for complex lists (e.g., user stories):

```text
initial_user_stories:
  - title: Create Event endpoint
    story: As an integrator, I want to POST an Event so it’s validated and stored.
    details: >
      Validate type, userId, and occurredAt; reject future timestamps.
```

Common pitfalls

- Don’t set `in_scope` or `out_of_scope` to a single scalar with `>` or `|`; they must be lists. Use `>` or `|` inside each list item if needed.
- No trailing commas in YAML arrays. Indent with spaces (not tabs).
- Quote list items that contain colons or `#`, or use `|`/`>` for those items to avoid parsing issues.

LLM generation guidance (recommended)
-------------------------------------

If an LLM will generate your `[jira_inputs]` block, use these guardrails to ensure it parses cleanly and passes validation:

Do:

- Output a single fenced code block labeled `text` that contains only the header line and the `[jira_inputs]...[/jira_inputs]` block.
- Use plain ASCII quotes (") and hyphens (-); avoid “smart quotes”.
- Use `>` or `|` for multi-line values; keep indentation with 2 spaces; no tabs.
- Keep booleans lowercase: `true` / `false`.
- Use 1–3 items for `initial_user_stories` and `expected_deliverables`, and 1–5 for `in_scope` when overriding.

Don’t:

- Don’t add explanations before/after the block.
- Don’t use trailing commas (YAML doesn’t allow them) or tabs.
- Don’t invent keys. Allowed keys are exactly: `jira_issue_key`, `use_jira_mcp`, `post_spec_to_jira`, `jira_comment_mode`, `main_idea`, `initial_user_stories`, `in_scope`, `out_of_scope`, `expected_deliverables`, `tech_constraints`, `requires_db_changes`, `requires_api_changes`, `spec_name_override`, `overwrite_existing`, `debug_extensions`.

Validation checklist (overrides path):

- If `use_jira_mcp: false` or Jira lacks fields, provide: `main_idea` (1–2 sentences), `initial_user_stories` (1–3), `in_scope` (1–5), `expected_deliverables` (1–3). `out_of_scope` and `tech_constraints` are optional.
- Use `requires_db_changes`/`requires_api_changes` to trigger conditional sub-specs when needed.

Commentless, machine-safe template (good for LLMs)
--------------------------------------------------

```text
@~/.agent-os/instructions/core/create-spec.md

[jira_inputs]
jira_issue_key: ""
use_jira_mcp: true
post_spec_to_jira: false
jira_comment_mode: summary
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
debug_extensions: false
[/jira_inputs]
```

Prompt to produce a valid block (copy to your LLM)
--------------------------------------------------

```text
Produce ONLY a fenced code block labeled text that contains this exact header line and a valid [jira_inputs] block.
Header line (first line):
@~/.agent-os/instructions/core/create-spec.md

Rules:
- Use YAML-compatible key:value pairs; booleans lowercase; quotes must be ASCII (").
- For any multi-line values, use YAML block scalars: > for folded, | for literal.
- Do not add any commentary before or after the code block.
- Use only these keys: jira_issue_key, use_jira_mcp, post_spec_to_jira, jira_comment_mode, main_idea, initial_user_stories, in_scope, out_of_scope, expected_deliverables, tech_constraints, requires_db_changes, requires_api_changes, spec_name_override, overwrite_existing, debug_extensions.
- If not using Jira mapping, include main_idea (1–2 sentences), 1–3 initial_user_stories, 1–5 in_scope, 1–3 expected_deliverables.
 - Required list types: in_scope, out_of_scope, initial_user_stories, expected_deliverables MUST be YAML lists (arrays). Prefer block style with dash items; do NOT emit a single scalar string for these keys.
 - Multi-line in lists: if a list item needs multiple lines, use > or | inside that list item (not on the key itself). Indent content by two spaces.
 - Quoting: quote any single-line list item that contains : or #, or use a block scalar (|/>) within that item to avoid YAML parsing issues.
 - Characters: use plain ASCII quotes ("), hyphen-minus (-); avoid smart quotes and en/em dashes.
 - Formatting: output exactly one fenced code block labeled text; do not include backticks inside the content of the block; use spaces (no tabs).
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
