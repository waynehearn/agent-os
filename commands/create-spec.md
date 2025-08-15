# Create Spec

Create a detailed spec for a new feature with technical specifications and task breakdown

IMPORTANT: Closely follow instructions located in @~/.agent-os/instructions/core/create-spec.md

Inputs (provide inline when invoking):

- Required: main_idea (1–2 sentences), initial_user_stories (1–3), in_scope (1–5), expected_deliverables (1–3)
- Optional: out_of_scope, tech_constraints, requires_db_changes, requires_api_changes, spec_name_override, overwrite_existing, post_spec_to_jira
- Atlassian MCP: you can pass jira_issue_key; the agent will fetch fields via Atlassian MCP and map them to inputs before proceeding
  - When started from Jira and MCP is available, the agent will post the generated spec.md as a Jira comment (deduplicated by hash)

Jira-driven example:

```text
@~/.agent-os/instructions/core/create-spec.md

[jira_inputs]
jira_issue_key: ABC-1234
use_jira_mcp: true
# Optional: disable auto Jira comment if desired
post_spec_to_jira: true
# Optional: choose how Jira comments are posted: full | diff | summary
jira_comment_mode: summary
# Optional overrides if Jira fields are missing
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

Manual input example:

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
