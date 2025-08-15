---
description: Rules to execute a task and its sub-tasks using Spec Agent Kibo
globs:
alwaysApply: false
version: 1.0
encoding: UTF-8
---

<!-- markdownlint-disable MD033 MD032 MD007 MD022 MD023 -->

# Task Execution Rules

## Overview

Execute a specific task along with its sub-tasks systematically following a TDD development workflow.

<pre_flight_check>
  EXECUTE: @~/.agent-os/instructions/meta/pre-flight.md
</pre_flight_check>


<variables>
  <spec_name>[SPEC_NAME]</spec_name>
  <spec_folder>[SPEC_FOLDER]</spec_folder>
  <spec_folder_path>[spec_folder_path]</spec_folder_path>
  <debug_subagents>false</debug_subagents>
  <debug_trace_redact_secrets>true</debug_trace_redact_secrets>
  <debug_trace_include_bodies>false</debug_trace_include_bodies>
  <debug_trace_dir>@[spec_folder_path]/debug/exec-trace</debug_trace_dir>
  <debug_task_log>@[debug_trace_dir]/task-[PARENT_TASK_NUMBER].log</debug_task_log>
</variables>


<process_flow>

<step number="0.9" name="task_trace_setup">

### Step 0.9: Task Trace Setup (debug)

Initialize per-task debug log if enabled.

<gate>
  RUN ONLY IF: [debug_subagents] == true
</gate>

<trace_setup>
  - CREATE directory if missing: @[debug_trace_dir]
  - OPEN/CREATE per-task log: @[debug_task_log]
  - WRITE an initial NDJSON line with {"ts":"[ISO8601]","action":"task-start","parentTask":[PARENT_TASK_NUMBER]}
</trace_setup>

</step>

<step number="1" name="task_understanding">

### Step 1: Task Understanding

Read and analyze the given parent task and all its sub-tasks from tasks.md to gain complete understanding of what needs to be built, using a lite-first approach.

<target>[spec_folder_path]/tasks.md</target>

<task_analysis>
  <read_from_tasks_md>
    - Extract only the current parent task block and its sub-tasks (create [spec_folder_path]/context/current-task.md optionally)
    - Parent task description
    - All sub-task descriptions
    - Task dependencies
    - Expected outcomes
  </read_from_tasks_md>
</task_analysis>

<instructions>
  ACTION: Read the specific parent task and all its sub-tasks
  ANALYZE: Full scope of implementation required
  UNDERSTAND: Dependencies and expected deliverables
  NOTE: Test requirements for each sub-task
</instructions>

</step>

<step number="2" name="technical_spec_review">

### Step 2: Technical Specification Review

Search and extract only the relevant sections from technical-spec.md (do not load the entire file) to understand the technical implementation approach for this task. Prefer using [spec_folder_path]/context/manifest.json to skip re-reading if unchanged.

<target>[spec_folder_path]/sub-specs/technical-spec.md</target>
<conditional>
  IF file missing:
    SKIP to Step 3
    NOTE lack of technical-spec.md in summary
</conditional>

<selective_reading>
  <search_technical_spec>
    FIND sections in technical-spec.md related to:
    - Current task functionality
    - Implementation approach for this feature
    - Integration requirements
    - Performance criteria
  </search_technical_spec>
</selective_reading>

<instructions>
  ACTION: Search technical-spec.md for task-relevant sections (by heading or anchors)
  EXTRACT: Only implementation details for current task
  SKIP: Unrelated technical specifications
  FOCUS: Technical approach for this specific feature
</instructions>

</step>

<step number="2.1" name="api_spec_review">

### Step 2.1: API Specification Review (Conditional)

Use a hybrid rule: read the API spec when the spec flags API work OR when the current task text clearly indicates API-related work. Prefer manifest-based skipping when unchanged.

<target>@[spec_folder_path]/sub-specs/api-spec.md</target>
<conditional>
  IF file missing:
    SKIP to Step 3
    NOTE lack of api-spec.md in summary
  ELSE IF one of the following is TRUE:
    - @[spec_folder_path]/meta.json exists AND requires_api_changes == true
    - The current parent task or any of its subtasks (from Step 1 snippet) contains API indicators (case-insensitive):
      ["API", "endpoint", "controller", "route", "router", "OpenAPI", "Swagger", "REST", "GraphQL", HTTP verbs like GET/POST/PUT/PATCH/DELETE with a path (e.g., "/", "/api/")]
    THEN:
      PROCEED to read relevant sections
    ELSE:
      SKIP to Step 3
      NOTE heuristics indicate no API work for this task
</conditional>

<selective_reading>
  <search_api_spec>
    FIND sections relevant to the current task, including:
    - Affected endpoints (HTTP method + path)
    - Request schema and validation rules
    - Response schema, status codes, and error shapes
    - Controller/handler mappings or notes
  </search_api_spec>
</selective_reading>

<instructions>
  ACTION: Read only the relevant endpoint sections from api-spec.md
  EXTRACT: Method, path, request/response types, validation, errors
  SKIP: Unrelated endpoints and sections
  APPLY: Contracts to guide tests-first and implementation steps
  NOTE: Use @[spec_folder_path]/context/manifest.json to avoid re-reading when sha256 unchanged
  DO_NOT_LOAD: decisions.md or full mission.md
  CHECK: @[spec_folder_path]/meta.json for requires_api_changes; OR rely on API indicators in current task text per the heuristic above
  </instructions>

<trace>
  IF [debug_subagents] == true:
    - BEFORE selective read: APPEND NDJSON to @[debug_task_log] with {"ts":"[ISO8601]","step":2.1,"action":"api-spec-check","gates":{"flag": "[requires_api_changes]","indicators":"[FOUND|NONE]"}}
    - AFTER selective read (if proceeded): APPEND with {"ts":"[ISO8601]","step":2.1,"action":"api-spec-read","status":"done","sections":"[SUMMARY]"}
</trace>

</step>

<step number="2.2" name="database_schema_review">

### Step 2.2: Database Schema Review (Conditional)

Use a hybrid rule: read the database schema sub-spec when the spec flags DB work OR when the current task text clearly indicates database-related work. Prefer manifest-based skipping when unchanged.

<target>@[spec_folder_path]/sub-specs/database-schema.md</target>
<conditional>
  IF file missing:
    SKIP to Step 3
    NOTE lack of database-schema.md in summary
  ELSE IF one of the following is TRUE:
    - @[spec_folder_path]/meta.json exists AND requires_db_changes == true
    - The current parent task or any of its subtasks (from Step 1 snippet) contains DB indicators (case-insensitive):
      ["DB", "database", "schema", "migration", "migrate", "table", "column", "index", "constraint", "foreign key", "SQL", "DDL", "EF migration", "Prisma migrate", "Liquibase", "Flyway"]
    THEN:
      PROCEED to read relevant sections
    ELSE:
      SKIP to Step 3
      NOTE heuristics indicate no DB work for this task
</conditional>

<selective_reading>
  <search_db_schema>
    FIND sections relevant to the current task, including:
    - New/modified tables, columns, indexes, constraints, relationships
    - Migration steps and ordering
    - Exact SQL or migration DSL snippets
    - Rollback/compatibility notes
  </search_db_schema>
</selective_reading>

<instructions>
  ACTION: Read only the relevant schema/migration sections from database-schema.md
  EXTRACT: Precise changes (tables/columns/indexes), migration order, and SQL/DSL
  SKIP: Unrelated schema areas
  APPLY: Use schema contracts to guide tests-first and implementation steps (including migration application)
  NOTE: Use @[spec_folder_path]/context/manifest.json to avoid re-reading when sha256 unchanged
  DO_NOT_LOAD: decisions.md or full mission.md
  CHECK: @[spec_folder_path]/meta.json for requires_db_changes; OR rely on DB indicators in current task text per the heuristic above
</instructions>

<trace>
  IF [debug_subagents] == true:
    - BEFORE selective read: APPEND NDJSON to @[debug_task_log] with {"ts":"[ISO8601]","step":2.2,"action":"db-spec-check","gates":{"flag":"[requires_db_changes]","indicators":"[FOUND|NONE]"}}
    - AFTER selective read (if proceeded): APPEND with {"ts":"[ISO8601]","step":2.2,"action":"db-spec-read","status":"done","sections":"[SUMMARY]"}
</trace>

</step>

<step number="3" subagent="context-fetcher" name="best_practices_review">

### Step 3: Best Practices Review

Use the context-fetcher subagent to retrieve only the relevant sections from @.agent-os/standards/best-practices.md that apply to the current task's technology stack and feature type. If [spec_folder_path]/context/manifest.json indicates unchanged, skip reload.

<selective_reading>
  <search_best_practices>
    FIND sections relevant to:
    - Task's technology stack
    - Feature type being implemented
    - Testing approaches needed
    - Code organization patterns
  </search_best_practices>
</selective_reading>

<instructions>
  ACTION: Use context-fetcher subagent
  REQUEST: "Find best practices sections relevant to:
            - Task's technology stack: [CURRENT_TECH]
            - Feature type: [CURRENT_FEATURE_TYPE]
            - Testing approaches needed
            - Code organization patterns"
  PROCESS: Returned best practices
  APPLY: Relevant patterns to implementation
</instructions>

<trace>
  IF [debug_subagents] == true:
    - BEFORE call: APPEND NDJSON to @[debug_task_log] with {"ts":"[ISO8601]","step":3,"subagent":"context-fetcher","action":"request","doc":"best-practices"}
    - AFTER call: APPEND NDJSON with {"ts":"[ISO8601]","step":3,"subagent":"context-fetcher","action":"response","sections":"[SUMMARY]","errors":[LIST_IF_ANY]}
</trace>

</step>

<step number="4" subagent="context-fetcher" name="code_style_review">

### Step 4: Code Style Review

Use the context-fetcher subagent to retrieve only the relevant code style rules from @.agent-os/standards/code-style.md for the languages and file types being used in this task. Use manifest-based skip when unchanged. If spec-lite.md or mission-lite.md are missing, proceed without them; rely on facts.md and spec.md sections as needed.

<selective_reading>
  <search_code_style>
    FIND style rules for:
    - Languages used in this task
    - File types being modified
    - Component patterns being implemented
    - Testing style guidelines
  </search_code_style>
</selective_reading>

<instructions>
  ACTION: Use context-fetcher subagent
  REQUEST: "Find code style rules for:
            - Languages: [LANGUAGES_IN_TASK]
            - File types: [FILE_TYPES_BEING_MODIFIED]
            - Component patterns: [PATTERNS_BEING_IMPLEMENTED]
            - Testing style guidelines"
  PROCESS: Returned style rules
  APPLY: Relevant formatting and patterns
  DO_NOT_LOAD: Full mission.md, decisions.md
</instructions>

<trace>
  IF [debug_subagents] == true:
    - BEFORE call: APPEND NDJSON to @[debug_task_log] with {"ts":"[ISO8601]","step":4,"subagent":"context-fetcher","action":"request","doc":"code-style","languages":"[LANGUAGES_IN_TASK]"}
    - AFTER call: APPEND NDJSON with {"ts":"[ISO8601]","step":4,"subagent":"context-fetcher","action":"response","rules":"[SUMMARY]","errors":[LIST_IF_ANY]}
</trace>

</step>

<step number="5" name="task_execution">

### Step 5: Task and Sub-task Execution

Execute the parent task and all sub-tasks in order using test-driven development (TDD) approach.

<typical_task_structure>
  <first_subtask>Write tests for [feature]</first_subtask>
  <middle_subtasks>Implementation steps</middle_subtasks>
  <final_subtask>Verify all tests pass</final_subtask>
</typical_task_structure>

<execution_order>
  <subtask_1_tests>
    IF sub-task 1 is "Write tests for [feature]":
      - Write all tests for the parent feature
      - Include unit tests, integration tests, edge cases
      - Run tests to ensure they fail appropriately
      - Mark sub-task 1 complete
  </subtask_1_tests>

  <middle_subtasks_implementation>
    FOR each implementation sub-task (2 through n-1):
      - Implement the specific functionality
      - Make relevant tests pass
      - Update any adjacent/related tests if needed
      - Refactor while keeping tests green
      - Mark sub-task complete
  </middle_subtasks_implementation>

  <final_subtask_verification>
    IF final sub-task is "Verify all tests pass":
      - Run entire test suite
      - Fix any remaining failures
      - Ensure no regressions
      - Mark final sub-task complete
  </final_subtask_verification>
</execution_order>

<test_management>
  <new_tests>
    - Written in first sub-task
    - Cover all aspects of parent feature
    - Include edge cases and error handling
  </new_tests>
  <test_updates>
    - Made during implementation sub-tasks
    - Update expectations for changed behavior
    - Maintain backward compatibility
  </test_updates>
</test_management>

<instructions>
  ACTION: Execute sub-tasks in their defined order
  RECOGNIZE: First sub-task typically writes all tests
  IMPLEMENT: Middle sub-tasks build functionality
  VERIFY: Final sub-task ensures all tests pass
  UPDATE: Mark each sub-task complete as finished
</instructions>

<trace>
  IF [debug_subagents] == true:
    - APPEND NDJSON to @[debug_task_log] for subtask transitions with {"ts":"[ISO8601]","step":5,"action":"subtask","number":"[SUBTASK_NUMBER]","status":"start|end"}
    - When running tests or commands, append summary lines (truncate bodies when [debug_trace_include_bodies] == false)
    - At end of step, append {"ts":"[ISO8601]","step":5,"action":"task-step-complete"}
</trace>

</step>

<step number="6" subagent="test-runner" name="task_test_verification">

### Step 6: Task-Specific Test Verification

Use the test-runner subagent to run and verify only the tests specific to this parent task (not the full test suite) to ensure the feature is working correctly.

<focused_test_execution>
  <run_only>
    - All new tests written for this parent task
    - All tests updated during this task
    - Tests directly related to this feature
  </run_only>
  <skip>
    - Full test suite (done later in execute-tasks.md)
    - Unrelated test files
  </skip>
</focused_test_execution>

<final_verification>
  IF any test failures:
    - Debug and fix the specific issue
    - Re-run only the failed tests
  ELSE:
    - Confirm all task tests passing
    - Ready to proceed
</final_verification>

<instructions>
  ACTION: Use test-runner subagent
  REQUEST: "Run tests for [this parent task's test files]"
  WAIT: For test-runner analysis
  PROCESS: Returned failure information
  VERIFY: 100% pass rate for task-specific tests
  CONFIRM: This feature's tests are complete
</instructions>

<trace>
  IF [debug_subagents] == true:
    - BEFORE call: APPEND NDJSON to @[debug_task_log] with {"ts":"[ISO8601]","step":6,"subagent":"test-runner","action":"request","scope":"task-tests"}
    - AFTER call: APPEND NDJSON with {"ts":"[ISO8601]","step":6,"subagent":"test-runner","action":"response","result":"pass|fail","failures":[...]} (truncate details when [debug_trace_include_bodies] == false)
</trace>

</step>

<step number="7" name="task_status_updates">

### Step 7: Task Status Updates

Update the tasks.md file immediately after completing each task to track progress.

<target>[spec_folder_path]/tasks.md</target>

<update_format>
  <completed>- [x] Task description</completed>
  <incomplete>- [ ] Task description</incomplete>
  <blocked>
    - [ ] Task description
    ⚠️ Blocking issue: [DESCRIPTION]
  </blocked>
</update_format>

<blocking_criteria>
  <attempts>maximum 3 different approaches</attempts>
  <action>document blocking issue</action>
  <emoji>⚠️</emoji>
</blocking_criteria>

<instructions>
  ACTION: Update tasks.md after each task completion
  MARK: [x] for completed items immediately
  DOCUMENT: Blocking issues with ⚠️ emoji
  LIMIT: 3 attempts before marking as blocked
</instructions>

</step>

</process_flow>

## Debug Log Format (NDJSON)

- Each line is standalone JSON with a timestamp and minimal fields.
- Secret redaction rules apply when `debug_trace_redact_secrets: true`.
- Parent run session log: `@[spec_folder_path]/debug/exec-trace/session.log`
- Per-task log: `@[spec_folder_path]/debug/exec-trace/task-[PARENT_TASK_NUMBER].log`
