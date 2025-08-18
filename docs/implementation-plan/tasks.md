# Tasks

## Task 1: Implement per-parent execution (run-execute-task.sh)

- [ ] parent checklist

### Subtask 1.1: Add selective reading using manifest and heuristics

- [ ] read technical-spec relevant sections only
- [ ] read api-spec only when API heuristics/flags true
- [ ] read database-schema only when DB heuristics/flags true

### Subtask 1.2: Implement TDD loop per execute-task.md

- [ ] write failing tests for the feature under the parent task
- [ ] implement functionality to pass tests
- [ ] verify task-specific tests pass

### Subtask 1.3: Minimal per-task debug logs

- [ ] log subagent requests/responses when debug_subagents=true
- [ ] summarize loaded vs. skipped documents

## Task 2: Add execute-tasks usage documentation and examples

- [ ] parent checklist

### Subtask 2.1: Write docs/execute-tasks-usage.md

- [ ] include artifact descriptions (current-task.md, tasks-summary.json, tasks-heuristics.json)
- [ ] include quick-start examples and flags

### Subtask 2.2: Link from docs/Index.md and commands/execute-tasks.md

- [ ] cross-link and ensure lint passes

## Task 3: Add focused tests for per-task runner

- [ ] parent checklist

### Subtask 3.1: CRLF portability tests

- [ ] add tasks with CRLF line endings and validate parsing

### Subtask 3.2: Heuristics gating tests

- [ ] assert API/DB reads occur only when indicated

## Task 4: Shared context management

- [x] parent checklist

### Subtask 4.1: Cross-command TTL cache + dedup

- [x] implement shared cache in context-cache-manager
		- Integrated cache usage in `tools/context-gatherer.sh` with flags/envs; uses shared cache manager when present.

### Subtask 4.2: Front-matter-only extension scanning

- [x] implement fast scan with skip list
		- Added `tools/extensions/extension-scanner.sh` and `test/test-extension-scanner.sh`; emits JSON with loaded/skipped and reasons; TTL cache-aware.
