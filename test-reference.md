
# Reference product Context

## Examples

[spec_inputs]
main_idea: >
  Create a Jira integration for Spec Agent K that allows users to create and update tickets from within the spec workflow.

initial_user_stories:

- title: Create Jira tickets from spec
  story: As a project manager, I want to create Jira tickets directly from specs, so that I can easily track feature development.
  details: When creating a specification, the system should offer an option to generate Jira tickets for tasks.

- title: Link specs to existing Jira tickets
  story: As a developer, I want to link specs to existing Jira tickets, so that I can maintain traceability.
  details: The system should allow users to reference existing tickets in the spec and create bidirectional links.

in_scope:

- Jira API integration for ticket creation
- Mapping spec tasks to Jira tickets
- Bidirectional linking between specs and Jira tickets
- Support for custom Jira fields
