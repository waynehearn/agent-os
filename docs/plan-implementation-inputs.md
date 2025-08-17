@~/.agent-os/instructions/core/plan-product.md

[plan_inputs]
main_idea: >
  Finalize Phase 2 for Agent OS and stage next-phase enhancements using a token-efficient, script-first approach
  with selective reading, section hashing, and manifest-driven skipping. Focus on execute-tasks per-parent
  runner, usage docs, and focused tests; then prepare shared context management and extensions architecture.

key_features:

- Implement per-parent execution (run-execute-task.sh) with selective reading and TDD loop
- Add execute-tasks usage documentation and examples
- Add focused tests for per-task runner (CRLF portability, heuristics)
- Shared context management (cross-command TTL cache, dedup)
- Extensions architecture improvements (discovery, compatibility, paths)

target_users:

- Agent OS maintainers and contributors
- Developers integrating token-efficient workflows

tech_stack_preferences: >
  Bash scripts (Git Bash compatible), jq; deterministic manifests + sha256; minimal external deps

project_initialized: yes
[/plan_inputs]
