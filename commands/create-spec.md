# Create Spec

Create a detailed spec for a new feature with technical specifications and task breakdown

IMPORTANT: Closely follow instructions located in @~/.agent-os/instructions/core/create-spec.md. The core flow is extensible: it automatically loads any matching extension files in `@~/.agent-os/instructions/extensions/create-spec/` (and optionally `@.agent-os/instructions/extensions/create-spec/`) that declare `targets: ["create-spec"]`.

Inputs (provide inline when invoking):

- Required: main_idea (1–2 sentences), initial_user_stories (1–3), in_scope (1–5), expected_deliverables (1–3)
- Optional: out_of_scope, tech_constraints, requires_db_changes, requires_api_changes, spec_name_override, overwrite_existing
- Extensions may add their own inputs. For Atlassian/Jira, install the optional extension at `instructions/extensions/create-spec/atlassian-jira.md` and use the `ext_*` variables shown below.

Jira-driven example (via optional extension):

```text
@~/.agent-os/instructions/core/create-spec.md

[jira_inputs]
ext_jira_issue_key: ABC-1234
ext_use_jira_mcp: true
# Optional: disable auto Jira comment if desired
ext_post_spec_to_jira: true
# Optional: choose how Jira comments are posted: full | diff | summary
ext_jira_comment_mode: summary
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
