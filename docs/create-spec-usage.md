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
Tip: To populate and refresh section-level hashes for targeted reloads, see [section-hashing.md](./section-hashing.md).
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

For Jira integration configuration, see the [canonical Jira key reference](jira-extension.md#canonical-jira-key-reference).

```text
@~/.agent-os/instructions/core/create-spec.md

[jira_inputs]
jira_issue_key: ABC-1234
use_jira_mcp: true
[/jira_inputs]
```

Enable discovery debug output (optional): add `debug_extensions: true` anywhere in the same input block to print and save the Extensions Discovery Report. See the [canonical Jira key reference](jira-extension.md#canonical-jira-key-reference) for all configuration options.

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

For complex examples with detailed overrides, see the [canonical Jira key reference](jira-extension.md#canonical-jira-key-reference) and the full examples in `docs/jira-extension.md`.

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

Discovery debug (optional): you can also add `debug_extensions: true` in `[spec_inputs]` to see which extensions would load for a manual run.

Determinism & Validation
------------------------

- Name normalization: kebab-case, ≤ 5 words
- Required core sections in `spec.md` in strict order: Overview, User Stories, Scope, Deliverables, Technical Details. API Specification and Database Changes are conditional and appended when applicable.
- Counts enforced: User Stories 1–3, Spec Scope 1–5, Expected Deliverables 1–3
- Post-write validation runs and repairs the file if needed
- `tasks.md` is validated and normalized right after creation

Skip-by-hash & selective reads
------------------------------

- During execution, the flows consult `context/manifest.json` (section-aware) to avoid re-loading unchanged files.
- They prefer `spec-lite.md`, `context/facts.md`, and task-scoped snippets over full-document loads.
- Strict do-not-load during execution: `decisions.md` and full `mission.md` (roadmap only when needed).

Hybrid consults (execution): When running execute-tasks/execute-task, the runner may selectively consult `sub-specs/api-spec.md` and `sub-specs/database-schema.md` using a hybrid rule:

- If `meta.json` flags `requires_api_changes`/`requires_db_changes` as true, or
- The current parent task/subtasks clearly include API/DB indicators (e.g., API/endpoint/controller/route/HTTP verb + path; DB/schema/migration/table/column/index/constraint)

These reads are minimal, section-scoped, and manifest-aware.

Idempotency
-----------

- If any target file exists and `overwrite_existing` is false, you will be asked before overwriting
- If you choose not to overwrite, the file is skipped and noted in the summary

Tips & Pitfalls
---------------

- Keep main_idea to 1–2 sentences; it drives the spec name if you don’t override
- Ensure deliverables are externally verifiable outcomes
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

Debugging execution (optional): add these flags to your execution block to trace subagent activity to NDJSON logs under `@[spec_folder_path]/debug/exec-trace/`:

```text
@~/.agent-os/instructions/core/execute-tasks.md

[execution_context]
spec_folder_path: @.agent-os/specs/YYYY-MM-DD-spec-name
debug_subagents: true
debug_trace_redact_secrets: true
debug_trace_include_bodies: false
[/execution_context]
```

## Schemas and Structure

### Spec Input Fields (Authoritative List)

JSON Schema: [schemas/spec-input.schema.json](./schemas/spec-input.schema.json)

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

### Required Section Order

#### spec.md Structure

1. **Overview** - Feature summary and goals
2. **User Stories** - Detailed user story breakdown
3. **Scope** - In-scope and out-of-scope items
4. **Deliverables** - Externally verifiable acceptance outcomes
5. **Technical Details** - Architecture, dependencies, constraints
6. **API Specification** - Endpoints, contracts, data models (if applicable)
7. **Database Changes** - Schema changes, migrations (if applicable)

#### tasks.md Structure

1. **Task Summary** - High-level breakdown
2. **Implementation Tasks** - Ordered list of development tasks
3. **Testing Tasks** - Validation and quality assurance tasks
4. **Documentation Tasks** - User guides, API docs, etc.
5. **Deployment Tasks** - Release and deployment activities

### Manifest Schema

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

#### Hashing Rules

- **Algorithm:** SHA256
- **Input:** File content with normalized line endings (LF only)
- **Encoding:** UTF-8
- **Update:** Hash regenerated on any content change

## Non-Interactive Mode

### Behavior

When `non_interactive: true` is set:

- **Equivalent to:** `--auto-approve` flag
- **User prompts:** Automatically answered with deterministic defaults
- **Confirmations:** Skipped with default choices logged
- **Validation errors:** Stop execution (no retry prompts)

### Default Responses

| Prompt Type | Default Response | Logged As |
|-------------|------------------|-----------|
| "Continue with spec creation?" | Yes | "DEFAULT: Continuing with spec creation" |
| "Overwrite existing spec?" | No | "DEFAULT: Preserving existing spec" |
| "Add more user stories?" | No | "DEFAULT: Using provided user stories only" |
| "Validate dependencies?" | Yes | "DEFAULT: Running dependency validation" |
| Extension prompts | Extension defaults | "DEFAULT: [extension-name] using defaults" |

### Logging Requirements

All skipped prompts and default choices must be logged with prefix "DEFAULT:" for audit trails.

### Example Usage

```yaml
# CI/CD pipeline usage
non_interactive: true
main_idea: "Automated feature from ticket ABC-123"
# ... other required fields
```

## Investigation Mode

### Overview

Investigation mode supports bug diagnosis, performance analysis, security audits, and exploratory development work. It creates structured investigation reports and can automatically generate actionable Jira tickets for implementation.

### When to Use Investigation Mode

- **Bug Diagnosis**: Root cause analysis for production issues
- **Performance Analysis**: Identifying bottlenecks and optimization opportunities
- **Security Audits**: Vulnerability assessment and threat analysis
- **Architecture Research**: Evaluating approaches for complex changes
- **Feasibility Studies**: Determining viability of proposed features

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

Investigation mode creates different outputs than standard specs:

#### Core Investigation Files

- `investigation-report.md` - Comprehensive findings and analysis
- `findings-summary.md` - Executive summary for stakeholders
- `action-items.md` - Prioritized next steps
- `jira-tickets.yaml` - Generated ticket definitions (if enabled)
- `implementation-specs.yaml` - Ready-to-use create-spec inputs

#### Investigation Report Structure

1. **Investigation Summary** - Type, scope, timeline, key questions
2. **Methodology** - Approach, tools used, data sources
3. **Key Findings** - Discoveries with supporting evidence
4. **Root Cause Analysis** - Primary causes and contributing factors
5. **Recommendations** - Immediate actions, short-term and long-term solutions
6. **Next Steps** - Implementation priorities and resource requirements

### Ticket Generation

When `generate_tickets: true` is set, the system automatically creates structured Jira tickets:

#### Ticket Categories

- **Immediate Fixes** - Critical bugs and security issues (High priority)
- **Improvement Opportunities** - Performance and UX enhancements (Medium priority)
- **Technical Debt** - Refactoring and maintenance work (Low-Medium priority)
- **New Features** - Capabilities identified during investigation (Medium priority)

#### Ticket Structure

Each generated ticket includes:

- Clear title and description with context
- Acceptance criteria based on investigation findings
- Priority assessment (High/Medium/Low)
- Links back to investigation report
- Appropriate labels and metadata
- Ready-to-use create-spec inputs for complex items

### Investigation → Implementation Flow

```bash
# 1. Run investigation
claude create-spec mode=investigate \
  investigation_type=performance \
  symptoms="Dashboard loads slowly" \
  generate_tickets=true \
  ticket_project_key="PERF"

# Outputs:
# - Investigation report with findings
# - 4 Jira tickets created automatically
# - 2 create-spec templates generated

# 2. Review tickets in Jira, prioritize work

# 3. Implement high-priority items
claude create-spec \
  jira_issue_key=PERF-123 \
  use_jira_mcp=true

# Or use generated spec template:
claude create-spec \
  @.agent-os/investigations/dashboard-performance/specs/database-optimization.yaml
```

### Example Investigation Scenarios

#### Database Performance Issue

```yaml
mode: investigate
investigation_type: performance
symptoms:
  - "API response times >3 seconds"
  - "Database CPU at 90% during business hours"
  - "Connection pool warnings in logs"
working_hypothesis: "Missing database indexes causing table scans"
affected_systems: ["api-gateway", "user-service", "postgres-primary"]
generate_tickets: true
ticket_project_key: "DB"
ticket_labels: ["performance", "database"]
```

#### Security Vulnerability Assessment

```yaml
mode: investigate
investigation_type: security
symptoms:
  - "Unusual authentication patterns detected"
  - "Increased failed login attempts"
  - "Suspicious API requests from new IP ranges"
affected_systems: ["auth-service", "rate-limiter", "api-gateway"]
generate_tickets: true
ticket_project_key: "SEC"
ticket_priority_default: "High"
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

Re-sync is manual by design. To update the Jira comment after editing `spec.md`, re-run Step 6.2 (extension) of `create-spec` with the same `jira_issue_key` and your preferred `jira_comment_mode`. The extension will dedupe by hash and only post a new comment when content changes.

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
