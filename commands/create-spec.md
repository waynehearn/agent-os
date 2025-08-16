# Create Spec

Create a detailed spec for a new feature with technical specifications and task breakdown

IMPORTANT: Closely follow instructions located in @~/.agent-os/instructions/core/create-spec.md. The core flow is extensible: it automatically loads any matching extension files in `@~/.agent-os/instructions/extensions/create-spec/` (and optionally `@.agent-os/instructions/extensions/create-spec/`) that declare `targets: ["create-spec"]`.

Inputs (provide inline when invoking):

- Required: main_idea (1–2 sentences), initial_user_stories (1–3), in_scope (1–5), expected_deliverables (1–3)
- Optional: mode (express|standard|investigate, default: standard)
- Optional: out_of_scope, tech_constraints, requires_db_changes, requires_api_changes, spec_name_override, overwrite_existing
- Extensions may add their own inputs.

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

mode: standard
spec_name_override: ""
overwrite_existing: false

# Investigation mode example:
# mode: investigate
# investigation_type: bug
# symptoms: ["Login returns 500 errors intermittently"]
# working_hypothesis: "Database connection pool exhaustion"
# generate_tickets: true
# ticket_project_key: "BUG"
[/spec_inputs]
```
