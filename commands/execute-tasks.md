# Execute Tasks

Execute one or more spec tasks using the Spec Agent K task loop.

Refer to the instructions located in @~/.agent-os/instructions/core/execute-tasks.md

Notes:

- The flow expects a spec context (e.g., [spec_folder_path]) and reads tasks from [spec_folder_path]/tasks.md
- Completion prints a visible banner and attempts a short beep when supported by the shell

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
