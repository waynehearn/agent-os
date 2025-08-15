---
description: Spec Creation Rules for Spec Agent Kibo
globs:
alwaysApply: false
version: 1.1
encoding: UTF-8
---

<!-- markdownlint-disable MD033 MD032 MD007 MD022 MD023 -->

# Spec Creation Rules

## Overview

Generate detailed feature specifications aligned with product roadmap and mission.

<pre_flight_check>
  EXECUTE: @~/.agent-os/instructions/meta/pre-flight.md
</pre_flight_check>

<variables>
  <spec_name>[SPEC_NAME]</spec_name>
  <spec_date>[CURRENT_DATE]</spec_date>
  <spec_folder>.agent-os/specs/[CURRENT_DATE]-[SPEC_NAME]</spec_folder>
  <spec_folder_path>@.agent-os/specs/[CURRENT_DATE]-[SPEC_NAME]</spec_folder_path>
  <requires_db_changes>false</requires_db_changes>
  <requires_api_changes>false</requires_api_changes>
  <debug_extensions>false</debug_extensions>
</variables>

<extensions_discovery>
  PURPOSE: Allow project- or team-specific behaviors to extend this core flow without changing it.

  LOOKUP PATHS (in order):
    1. @~/.agent-os/instructions/extensions/create-spec/**/*.md
    2. @.agent-os/instructions/extensions/create-spec/**/*.md (project-local, optional)

  CONVENTION:
    - Extension files MUST include front matter with: `targets: ["create-spec"]`.
  - Optional front matter key `requires: ["capability"]` may declare dependencies (e.g., `mcp:atlassian`).
    - Extensions may declare additional <variables> and <step> blocks.
    - Steps are merged into this process by their numeric `number` attribute (e.g., 1.1, 6.2).
    - Core steps keep their numbers; extensions should use decimal positions that don’t collide.
    - If a collision occurs, run core step first, then the extension step.

  SAFE MERGE RULES:
    - Variable names should be distinct; extensions should prefer namespaced keys (e.g., ext_<vendor>_*).
    - Determinism and validation rules from core always apply.
    - Extensions MUST be optional; if no matching files are found, run core steps only.

  EXECUTION:
    - Before processing <process_flow>, DISCOVER candidate files per paths above.
    - For each candidate, READ only front matter to check `targets` and optional `requires`.
      - If `requires` includes a capability that is not available in the runtime (e.g., `mcp:atlassian` and no Atlassian MCP), SKIP the file without loading its body.
    - From the remaining files, COLLECT their <step> blocks that declare `targets: ["create-spec"]`.
    - MERGE the collected steps into the ordered flow by step number.

  DEBUGGING (optional):
    - Toggle `[debug_extensions]` to `true` to emit an "Extensions Discovery Report" before Step 1.
    - The report MUST list, for each candidate file:
      - path (logical @-path), vendor (from front matter if present), targets, requires
      - decision: LOADED or SKIPPED
      - reason when SKIPPED: missing capability (e.g., requires mcp:... not available), targets mismatch, parse error, or other
    - Also include a one-line summary of detected capabilities (if your runtime exposes them), e.g., `capabilities: [mcp:atlassian, ...]`.
</extensions_discovery>

<determinism_rules>

- All generated files MUST be placed under [spec_folder_path].
- Section headers in spec.md MUST appear in exactly this order: Overview, User Stories, Spec Scope, Out of Scope, Expected Deliverable.
- Counts:
  - User Stories: 1-3
  - Spec Scope items: 1-5
  - Expected Deliverables: 1-3 (browser-testable)
- Tone: concise, declarative, aligned with project style.
- Idempotency: if any target file exists, ASK user to overwrite (yes/no). On "no", SKIP creation for that file and report in summary.

</determinism_rules>

<process_flow>

<step number="0.9" subagent="context-fetcher" name="extensions_discovery_report">

### Step 0.9: Extensions Discovery Report (debug)

Emit a concise report of extension discovery outcomes before the main flow begins.

<gate>
  RUN ONLY IF: [debug_extensions] == true
</gate>

<report_format>
  - Print a header: "Extensions Discovery Report"
  - If available, list `capabilities: [CAP_1, CAP_2, ...]`
  - For each candidate file discovered in the lookup paths, print one line with:
    - status: LOADED | SKIPPED
    - reason (if SKIPPED)
    - path (logical), vendor, targets, requires
  - End with a summary count: `loaded: N, skipped: M`
  - Then print a "Merged step order (preview)" that lists the final ordered steps by number and name, including extension steps. On collisions, show core step first, then extension step(s).
  - Include a source tag for each item: [core] for core steps, [ext:<vendor-or-file>] for extension steps (use `vendor` from front matter when available, otherwise the file basename).
</report_format>

<persist_report>
  - Create directory if missing: @[spec_folder_path]/debug/
  - Save the exact printed report to: @[spec_folder_path]/debug/extensions-discovery.txt
  - Overwrite on subsequent runs to keep the latest report
</persist_report>

</step>

<step number="1" subagent="context-fetcher" name="spec_initiation">

### Step 1: Spec Initiation

Use the context-fetcher subagent to identify spec initiation method by either finding the next uncompleted roadmap item when user asks "what's next?" or accepting a specific spec idea from the user.

Note: Additional initiation sources (e.g., external ticket systems) may be provided by installed extensions and will be merged into this flow automatically.

<inputs_validation>
  <schema>
    - main_idea: required string (1-2 sentences)
    - initial_user_stories: required array[min=1, max=3]
    - in_scope: required array[min=1, max=5]
    - out_of_scope: optional array
    - expected_deliverables: required array[min=1, max=3]
    - tech_constraints: optional string
  </schema>
  <gate>
    IF any required fields missing:
      SHOW error_template
      STOP before Step 2
  </gate>
  <error_template>
    Missing required inputs:
    - [LIST_MISSING_FIELDS]
    Please provide missing fields to proceed.
  </error_template>
</inputs_validation>

<whats_next_flow>
  <trigger_phrases>
    - "what's next?"
  </trigger_phrases>
  <actions>
    1. CHECK @.agent-os/product/roadmap.md
    2. FIND next uncompleted item
    3. SUGGEST item to user
    4. WAIT for approval
  </actions>
</whats_next_flow>

<!-- Jira/Atlassian or other ticket integrations are provided by extensions (if installed). -->

<specific_spec_idea_flow>
  <trigger>user describes specific spec idea</trigger>
  <accept>any format, length, or detail level</accept>
  <proceed>to context gathering</proceed>
</specific_spec_idea_flow>

</step>

<step number="2" subagent="context-fetcher" name="context_gathering">

### Step 2: Context Gathering (Conditional)

Use the context-fetcher subagent to read @.agent-os/product/mission-lite.md and @.agent-os/standards/tech-stack.md only if not already in context to ensure minimal context for spec alignment.

<conditional_logic>
  IF both mission-lite.md AND tech-stack.md already read in current context:
    SKIP this entire step
    PROCEED to step 3
  ELSE:
    READ only files not already in context AND present on disk:
      - mission-lite.md (if not in context AND file exists)
      - tech-stack.md (if not in context AND file exists)
    IF mission-lite.md is missing:
      NOTE: proceed without mission-lite.md (not required when starting via analyze-product or Jira); rely on inputs and tech-stack
    CONTINUE with context analysis
</conditional_logic>

<lite_first_and_cache>
  - NEVER load full mission.md or roadmap.md during spec creation; use mission-lite.md only.
  - BEFORE reading a file, CHECK [spec_folder_path]/context/manifest.json:
    - IF entry exists for the target file AND sha256 matches current file on disk:
      SKIP reading; treat as already in context.
    - ELSE:
      READ only the exact sections requested by this step (avoid full-file loads when possible).
      AFTER read, UPDATE manifest.json with new sha256 and lastModified.
  - PREFERRED sources for alignment: mission-lite.md -> spec-lite.md (later) -> spec.md sections only when required by validation.
</lite_first_and_cache>

<context_analysis>
  <mission_lite>core product purpose and value</mission_lite>
  <tech_stack>technical requirements</tech_stack>
</context_analysis>

</step>

<step number="3" subagent="context-fetcher" name="requirements_clarification">

### Step 3: Requirements Clarification

Use the context-fetcher subagent to clarify scope boundaries and technical considerations by asking numbered questions as needed to ensure clear requirements before proceeding.

<clarification_areas>
  <scope>
    - in_scope: what is included
    - out_of_scope: what is excluded (optional)
  </scope>
  <technical>
    - functionality specifics
    - UI/UX requirements
    - integration points
  </technical>
</clarification_areas>

<decision_tree>
  IF clarification_needed:
    ASK numbered_questions
    WAIT for_user_response
  ELSE:
    PROCEED to_date_determination
</decision_tree>

</step>

<step number="4" subagent="date-checker" name="date_determination">

### Step 4: Date Determination

Use the date-checker subagent to determine the current date in YYYY-MM-DD format for folder naming. The subagent will output today's date which will be used in subsequent steps.

<subagent_output>
  The date-checker subagent will provide the current date in YYYY-MM-DD format at the end of its response. Store this date for use in folder naming in step 5.
</subagent_output>

</step>

<step number="5" subagent="file-creator" name="spec_folder_creation">

### Step 5: Spec Folder Creation

Use the file-creator subagent to create directory: .agent-os/specs/YYYY-MM-DD-spec-name/ using the date from step 4.

Use kebab-case for spec name. Maximum 5 words in name.

<folder_naming>
  <format>YYYY-MM-DD-spec-name</format>
  <date>use stored date from step 4</date>
  <name_constraints>
    - max_words: 5
    - style: kebab-case
    - descriptive: true
  </name_constraints>
</folder_naming>

<name_normalization>
  EXECUTE: @~/.agent-os/instructions/core/spec-name-normalizer.md with INPUT_NAME=[USER_PROVIDED_TITLE_OR_MAIN_IDEA]
  SET: SPEC_NAME <- [OUTPUT_SPEC_NAME]
</name_normalization>

<example_names>
  - 2025-03-15-password-reset-flow
  - 2025-03-16-user-profile-dashboard
  - 2025-03-17-api-rate-limiting
</example_names>

<paths_to_create>
  - [spec_folder_path]/
  - [spec_folder_path]/sub-specs/
  - [spec_folder_path]/context/
</paths_to_create>

</step>

<step number="6" subagent="file-creator" name="create_spec_md">

### Step 6: Create spec.md

Use the file-creator subagent to create the file: .agent-os/specs/YYYY-MM-DD-spec-name/spec.md using this template:

<target>[spec_folder_path]/spec.md</target>

<file_template>
  <header>
    # Spec Requirements Document

    > Spec: [SPEC_NAME]
    > Created: [CURRENT_DATE]
  </header>
  <required_sections>
    - Overview
    - User Stories
    - Spec Scope
    - Out of Scope
    - Expected Deliverable
  </required_sections>
</file_template>

<section name="overview">
  <template>
    ## Overview

    [1-2_SENTENCE_GOAL_AND_OBJECTIVE]
  </template>
  <constraints>
    - length: 1-2 sentences
    - content: goal and objective
  </constraints>
  <example>
    Implement a secure password reset functionality that allows users to regain account access through email verification. This feature will reduce support ticket volume and improve user experience by providing self-service account recovery.
  </example>
</section>

<section name="user_stories">
  <template>
    ## User Stories

    ### [STORY_TITLE]

    As a [USER_TYPE], I want to [ACTION], so that [BENEFIT].

    [DETAILED_WORKFLOW_DESCRIPTION]
  </template>
  <constraints>
    - count: 1-3 stories
    - include: workflow and problem solved
    - format: title + story + details
  </constraints>
</section>

<section name="spec_scope">
  <template>
    ## Spec Scope

    1. **[FEATURE_NAME]** - [ONE_SENTENCE_DESCRIPTION]
    2. **[FEATURE_NAME]** - [ONE_SENTENCE_DESCRIPTION]
  </template>
  <constraints>
    - count: 1-5 features
    - format: numbered list
    - description: one sentence each
  </constraints>
</section>

<section name="out_of_scope">
  <template>
    ## Out of Scope

    - [EXCLUDED_FUNCTIONALITY_1]
    - [EXCLUDED_FUNCTIONALITY_2]
  </template>
  <purpose>explicitly exclude functionalities</purpose>
</section>

<section name="expected_deliverable">
  <template>
    ## Expected Deliverable

    1. [TESTABLE_OUTCOME_1]
    2. [TESTABLE_OUTCOME_2]
  </template>
  <constraints>
    - count: 1-3 expectations
    - focus: browser-testable outcomes
  </constraints>
</section>

<post_write_validation>
  VERIFY file [spec_folder_path]/spec.md contains required sections in exact order: Overview, User Stories, Spec Scope, Out of Scope, Expected Deliverable.
  VERIFY counts: User Stories 1-3, Spec Scope 1-5, Expected Deliverable 1-3.
  IF validation fails:
    REWRITE sections to satisfy constraints without duplicating content.
  THEN:
    EXECUTE: @~/.agent-os/instructions/core/spec-validator.md with SPEC_PATH=@[spec_folder_path]/spec.md
</post_write_validation>

</step>

<step number="6.1" subagent="file-creator" name="emit_lite_context_artifacts">

### Step 6.1: Emit Lite Context Artifacts

Create lightweight, cached context artifacts for fast, deterministic reuse.

<targets>
  - [spec_folder_path]/meta.json
  - [spec_folder_path]/context/facts.md
  - [spec_folder_path]/context/manifest.json
  - [spec_folder_path]/context/.gitkeep (optional)
</targets>

<meta_json_template>
{
  "spec_key": "[CURRENT_DATE]-[SPEC_NAME]",
  "spec_name": "[SPEC_NAME]",
  "spec_date": "[CURRENT_DATE]",
  "requires_db_changes": [requires_db_changes],
  "requires_api_changes": [requires_api_changes],
  "section_counts": {
    "user_stories": "[COUNT_FROM_SPEC]",
    "spec_scope": "[COUNT_FROM_SPEC]",
    "expected_deliverables": "[COUNT_FROM_SPEC]"
  }
}
</meta_json_template>

<facts_md_template>
  ## Context Facts

  - Mission (lite): [ONE_SENTENCE_FROM @.agent-os/product/mission-lite.md OR N/A]
  - Spec: [SPEC_NAME] ([CURRENT_DATE])
  - Primary deliverables (1–3):
    - [FROM Expected Deliverable]
  - Constraints/assumptions:
    - [e.g., tech constraints, out-of-scope highlights]
  - Notes:
    - This file is the canonical lite context for execution flows.
</facts_md_template>

<manifest_json_template>
{
  "docs": {
    "mission-lite.md": { "path": "@.agent-os/product/mission-lite.md", "sha256": "[HASH]", "lastModified": "[ISO8601]" },
    "spec.md": { "path": "@[spec_folder_path]/spec.md", "sha256": "[HASH]", "lastModified": "[ISO8601]" },
    "spec-lite.md": { "path": "@[spec_folder_path]/spec-lite.md", "sha256": "[PENDING_UNTIL_STEP7]", "lastModified": "" },
    "technical-spec.md": { "path": "@[spec_folder_path]/sub-specs/technical-spec.md", "sha256": "[HASH]", "lastModified": "[ISO8601]" }
  }
}
</manifest_json_template>

<instructions>
  ACTION: Count sections in spec.md after validation and write meta.json
  ACTION: Summarize mission-lite and expected deliverables into context/facts.md
  ACTION: Compute initial doc hashes and write context/manifest.json (update spec-lite after Step 7)
</instructions>

</step>

<step number="7" subagent="file-creator" name="create_spec_lite_md">

### Step 7: Create spec-lite.md

Use the file-creator subagent to create the file: .agent-os/specs/YYYY-MM-DD-spec-name/spec-lite.md for the purpose of establishing a condensed spec for efficient AI context usage.

<target>[spec_folder_path]/spec-lite.md</target>

<file_template>
  <header>
    # Spec Summary (Lite)
  </header>
</file_template>

<content_structure>
  <spec_summary>
    - source: Step 6 spec.md overview section
    - length: 1-3 sentences
    - content: core goal and objective of the feature
  </spec_summary>
</content_structure>

<content_template>
  [1-3_SENTENCES_SUMMARIZING_SPEC_GOAL_AND_OBJECTIVE]
</content_template>

<example>
  Implement secure password reset via email verification to reduce support tickets and enable self-service account recovery. Users can request a reset link, receive a time-limited token via email, and set a new password following security best practices.
</example>

</step>

<step number="7.1" name="update_manifest_for_spec_lite">

### Step 7.1: Update Manifest for spec-lite.md

After creating spec-lite.md, update its entry in [spec_folder_path]/context/manifest.json with sha256 and lastModified.

</step>

<step number="8" subagent="file-creator" name="create_technical_spec">

### Step 8: Create Technical Specification

Use the file-creator subagent to create the file: sub-specs/technical-spec.md using this template:

<target>[spec_folder_path]/sub-specs/technical-spec.md</target>

<file_template>
  <header>
    # Technical Specification

  This is the technical specification for the spec detailed in @[spec_folder_path]/spec.md
  </header>
</file_template>

<spec_sections>
  <technical_requirements>
    - functionality details
    - UI/UX specifications
    - integration requirements
    - performance criteria
  </technical_requirements>
  <external_dependencies_conditional>
    - only include if new dependencies needed
    - new libraries/packages
    - justification for each
    - version requirements
  </external_dependencies_conditional>
</spec_sections>

<example_template>
  ## Technical Requirements

  - [SPECIFIC_TECHNICAL_REQUIREMENT]
  - [SPECIFIC_TECHNICAL_REQUIREMENT]

  ## External Dependencies (Conditional)

  [ONLY_IF_NEW_DEPENDENCIES_NEEDED]
  - **[LIBRARY_NAME]** - [PURPOSE]
  - **Justification:** [REASON_FOR_INCLUSION]
</example_template>

<conditional_logic>
  IF spec_requires_new_external_dependencies:
    INCLUDE "External Dependencies" section
  ELSE:
    OMIT section entirely
</conditional_logic>

</step>

<step number="9" subagent="file-creator" name="create_database_schema">

### Step 9: Create Database Schema (Conditional)

Use the file-creator subagent to create the file: sub-specs/database-schema.md ONLY IF database changes needed for this task.

<condition_flag>[requires_db_changes] == true</condition_flag>
<target>[spec_folder_path]/sub-specs/database-schema.md</target>

<decision_tree>
  IF spec_requires_database_changes:
    CREATE sub-specs/database-schema.md
  ELSE:
    SKIP this_step
</decision_tree>

<file_template>
  <header>
    # Database Schema

  This is the database schema implementation for the spec detailed in @[spec_folder_path]/spec.md
  </header>
</file_template>

<schema_sections>
  <changes>
    - new tables
    - new columns
    - modifications
    - migrations
  </changes>
  <specifications>
    - exact SQL or migration syntax
    - indexes and constraints
    - foreign key relationships
  </specifications>
  <rationale>
    - reason for each change
    - performance considerations
    - data integrity rules
  </rationale>
</schema_sections>

</step>

<step number="10" subagent="file-creator" name="create_api_spec">

### Step 10: Create API Specification (Conditional)

Use the file-creator subagent to create file: sub-specs/api-spec.md ONLY IF API changes needed.

<condition_flag>[requires_api_changes] == true</condition_flag>
<target>[spec_folder_path]/sub-specs/api-spec.md</target>

<decision_tree>
  IF spec_requires_api_changes:
    CREATE sub-specs/api-spec.md
  ELSE:
    SKIP this_step
</decision_tree>

<file_template>
  <header>
    # API Specification

  This is the API specification for the spec detailed in @[spec_folder_path]/spec.md
  </header>
</file_template>

<api_sections>
  <routes>
    - HTTP method
    - endpoint path
    - parameters
    - response format
  </routes>
  <controllers>
    - action names
    - business logic
    - error handling
  </controllers>
  <purpose>
    - endpoint rationale
    - integration with features
  </purpose>
</api_sections>

<endpoint_template>
  ## Endpoints

  ### [HTTP_METHOD] [ENDPOINT_PATH]

  **Purpose:** [DESCRIPTION]
  **Parameters:** [LIST]
  **Response:** [FORMAT]
  **Errors:** [POSSIBLE_ERRORS]
</endpoint_template>

</step>

<step number="11" name="user_review">

### Step 11: User Review

Request user review of spec.md and all sub-specs files, waiting for approval or revision requests before proceeding to task creation.

<review_request>
  I've created the spec documentation:

  - Spec Requirements: @[spec_folder_path]/spec.md
  - Spec Summary: @[spec_folder_path]/spec-lite.md
  - Technical Spec: @[spec_folder_path]/sub-specs/technical-spec.md
  [LIST_OTHER_CREATED_SPECS]

  Please review and let me know if any changes are needed before I create the task breakdown.
</review_request>

</step>

<step number="12" subagent="file-creator" name="create_tasks">

### Step 12: Create tasks.md

Use the file-creator subagent to await user approval from step 11 and then create file: tasks.md

<target>[spec_folder_path]/tasks.md</target>

<file_template>
  <header>
    # Spec Tasks
  </header>
</file_template>

<task_structure>
  <major_tasks>
    - count: 1-5
    - format: numbered checklist
    - grouping: by feature or component
  </major_tasks>
  <subtasks>
    - count: up to 8 per major task
    - format: decimal notation (1.1, 1.2)
    - first_subtask: typically write tests
    - last_subtask: verify all tests pass
  </subtasks>
</task_structure>

<task_template>
  ## Tasks

  - [ ] 1. [MAJOR_TASK_DESCRIPTION]
    - [ ] 1.1 Write tests for [COMPONENT]
    - [ ] 1.2 [IMPLEMENTATION_STEP]
    - [ ] 1.3 [IMPLEMENTATION_STEP]
    - [ ] 1.4 Verify all tests pass

  - [ ] 2. [MAJOR_TASK_DESCRIPTION]
    - [ ] 2.1 Write tests for [COMPONENT]
    - [ ] 2.2 [IMPLEMENTATION_STEP]
</task_template>

<ordering_principles>
  - Consider technical dependencies
  - Follow TDD approach
  - Group related functionality
  - Build incrementally
</ordering_principles>

</step>

<step number="12.1" name="validate_tasks">

### Step 12.1: Validate tasks.md

Run tasks validation to ensure structure, numbering, and required items are present.

<execute_validator>
  EXECUTE: @~/.agent-os/instructions/core/tasks-validator.md with TASKS_PATH=@[spec_folder_path]/tasks.md
</execute_validator>

</step>

<step number="12.2" name="facts_first_task_summary">

### Step 12.2: Update Facts with First Task Summary

Append a short summary of Task 1 (title + 1–2 sentence description) to [spec_folder_path]/context/facts.md and update context/manifest.json hash for tasks.md and facts.md.

</step>

<step number="13" name="decision_documentation">

### Step 13: Decision Documentation (Conditional)

Evaluate strategic impact without loading decisions.md and update it only if there's significant deviation from mission/roadmap and user approves.

<conditional_reads>
  IF mission-lite.md NOT in context:
    USE: context-fetcher subagent
    REQUEST: "Get product pitch from mission-lite.md"
  IF roadmap.md NOT in context:
    USE: context-fetcher subagent
    REQUEST: "Get current development phase from roadmap.md"

  <manual_reads>
    <mission_lite>
      - IF NOT already in context: READ @.agent-os/product/mission-lite.md
      - IF already in context: SKIP reading
    </mission_lite>
    <roadmap>
      - IF NOT already in context: READ @.agent-os/product/roadmap.md
      - IF already in context: SKIP reading
    </roadmap>
    <decisions>
      - NEVER load decisions.md into context
    </decisions>
  </manual_reads>
</conditional_reads>

<decision_analysis>
  <review_against>
    - @.agent-os/product/mission-lite.md (conditional)
    - @.agent-os/product/roadmap.md (conditional)
  </review_against>
  <criteria>
    - significantly deviates from mission in mission-lite.md
    - significantly changes or conflicts with roadmap.md
  </criteria>
</decision_analysis>

<decision_tree>
  IF spec_does_NOT_significantly_deviate:
    SKIP this entire step
    STATE "Spec aligns with mission and roadmap"
    PROCEED to step 14
  ELSE IF spec_significantly_deviates:
    EXPLAIN the significant deviation
    ASK user: "This spec significantly deviates from our mission/roadmap. Should I draft a decision entry?"
    IF user_approves:
      DRAFT decision entry
      UPDATE decisions.md
    ELSE:
      SKIP updating decisions.md
      PROCEED to step 14
</decision_tree>

<decision_template>
  ## [CURRENT_DATE]: [DECISION_TITLE]

  **ID:** DEC-[NEXT_NUMBER]
  **Status:** Accepted
  **Category:** [technical/product/business/process]
  **Related Spec:** @[spec_folder_path]/

  ### Decision

  [DECISION_SUMMARY]

  ### Context

  [WHY_THIS_DECISION_WAS_NEEDED]

  ### Deviation

  [SPECIFIC_DEVIATION_FROM_MISSION_OR_ROADMAP]
</decision_template>

</step>

<step number="14" name="execution_readiness">

### Step 14: Execution Readiness Check

Evaluate readiness to begin implementation after completing all previous steps, presenting the first task summary and requesting user confirmation to proceed.

<readiness_summary>
  <present_to_user>
    - Spec name and description
    - First task summary from tasks.md
    - Estimated complexity/scope
    - Key deliverables for task 1
  </present_to_user>
</readiness_summary>

<execution_prompt>
  PROMPT: "The spec planning is complete. The first task is:

  **Task 1:** [FIRST_TASK_TITLE]
  [BRIEF_DESCRIPTION_OF_TASK_1_AND_SUBTASKS]

  Would you like me to proceed with implementing Task 1? I will focus only on this first task and its subtasks unless you specify otherwise.

  Type 'yes' to proceed with Task 1, or let me know if you'd like to review or modify the plan first."
</execution_prompt>

<execution_flow>
  IF user_confirms_yes:
    REFERENCE: @~/.agent-os/instructions/core/execute-tasks.md
    FOCUS: Only Task 1 and its subtasks
    CONSTRAINT: Do not proceed to additional tasks without explicit user request
  ELSE:
    WAIT: For user clarification or modifications
</execution_flow>

</step>

</process_flow>

## Execution Standards

<standards>
  <follow>
  - @.agent-os/standards/code-style.md
  - @.agent-os/standards/best-practices.md
  - @.agent-os/standards/tech-stack.md
  </follow>
  <maintain>
    - Consistency with product mission
    - Alignment with roadmap
    - Technical coherence
  </maintain>
  <create>
    - Comprehensive documentation
    - Clear implementation path
    - Testable outcomes
  </create>
</standards>

<final_checklist>
  <verify>
    - [ ] Accurate date determined via file system
    - [ ] Spec folder created with correct date prefix
    - [ ] spec.md contains all required sections
    - [ ] All applicable sub-specs created
    - [ ] User approved documentation
    - [ ] tasks.md created with TDD approach
    - [ ] Cross-references added to spec.md
    - [ ] Strategic decisions evaluated
  - [ ] context/facts.md created and populated
  - [ ] context/manifest.json created and updated
  - [ ] meta.json created with section counts and flags
  </verify>
</final_checklist>
