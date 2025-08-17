# Execute Tasks

Execute one or more spec tasks using the Spec Agent K task loop.

Refer to the instructions located in @~/.agent-os/instructions/core/execute-tasks.md

Notes:

- The flow expects a spec context (e.g., [spec_folder_path]) and reads tasks from [spec_folder_path]/tasks.md
- Completion prints a visible banner and attempts a short beep when supported by the shell
- When using the script implementation (tools/execute-tasks.sh), the following artifacts are written prior to executing a parent task:
  - [spec_folder_path]/context/current-task.md (deterministic snippet of the current parent block)
  - [spec_folder_path]/context/tasks-summary.json (parent number/title, first/last subtask presence)
  - [spec_folder_path]/context/manifest.json is refreshed for tasks.md to support selective reloads
  - When delegated to per-task runner (tools/run-execute-task.sh), selective-reading extracts may also be written:
    - [spec_folder_path]/context/selected-technical.md
    - [spec_folder_path]/context/selected-api.md (gated)
    - [spec_folder_path]/context/selected-db.md (gated)

Optional TDD loop (script-mode):

- Set `ENABLE_TDD_LOOP=1` to enable an optional focused test run via `tools/test-runner.sh`.
- Provide a shell command in `TEST_CMD` to actually run your tests (e.g., `npm test -- -t "greeting"`).
- A compact summary is written to `[spec_folder_path]/context/test-run-summary.json`.
- Optional envs:
  - `TEST_PATTERN` to pass a test selector (also seeds from the first line of `execution_notes` when present)
  - `TEST_RETRIES` to retry failing runs a few times (default: 0)
  - If `TEST_PATTERN` is not provided, a compact default is inferred from the parent task title (first 1–2 meaningful words)

Examples:

Run next uncompleted task for a spec:

```text
@~/.agent-os/instructions/core/execute-tasks.md

[execution_context]
spec_folder_path: @.agent-os/specs/2025-08-12-location-patch-support
[/execution_context]
```

Run specific parent tasks (by number) for a spec:

```text
@~/.agent-os/instructions/core/execute-tasks.md

[execution_context]
spec_folder_path: @.agent-os/specs/2025-08-12-location-patch-support
specific_tasks:
  - 1
  - 3
[/execution_context]
```

Run only subtask 1.1 for task 1:

```text
@~/.agent-os/instructions/core/execute-tasks.md

[execution_context]
spec_folder_path: @.agent-os/specs/2025-08-12-location-patch-support
specific_tasks:
  - 1
execution_notes: >
  Execute only subtask 1.1 for task 1 and stop after verifying tests for that subtask.
[/execution_context]
```

Optional: enable TDD loop and supply a test command (bash env):

```bash
ENABLE_TDD_LOOP=1 TEST_CMD="npm test -- -t \"Greeting API\"" TEST_PATTERN="Greeting" TEST_RETRIES=1 bash tools/run-execute-task.sh path/to/inputs.md
```
