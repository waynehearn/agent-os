---
title: Spec Agent Kibo – Start here
version: 1.0
lastUpdated: 2025-08-14
---

Welcome
-------

Spec Agent Kibo is your system for spec‑driven agentic development. It gives AI coding agents structured workflows aligned to your standards, stack, and codebase context so they ship quality code on the first try—not the fifth.

Start here (10–15 minutes)
--------------------------

1. [installation.md](./installation.md)
2. [quickstart.md](./quickstart.md)
3. [create-spec-usage.md](./create-spec-usage.md)
4. [create-spec-steps.md](./create-spec-steps.md)
5. [jira-extension.md](./jira-extension.md) (optional)
6. [task-organization-hints.md](./task-organization-hints.md) (optional)
7. [smoke-tests.md](./smoke-tests.md)

Navigation
----------

- Usage guide: [create-spec-usage.md](./create-spec-usage.md)
- Create-spec steps: [create-spec-steps.md](./create-spec-steps.md)
- Task creation details: [create-spec-tasks.md](./create-spec-tasks.md)
- Installation: [installation.md](./installation.md)
- Configuration: [configuration.md](./configuration.md)
- Extensions Quickstart: [extensions-quickstart.md](./extensions-quickstart.md)
- Task ordering hints: [task-organization-hints.md](./task-organization-hints.md)
- Quickstart: [quickstart.md](./quickstart.md)
- Smoke tests: [smoke-tests.md](./smoke-tests.md)
- Troubleshooting: [troubleshooting.md](./troubleshooting.md)
- Glossary: [glossary.md](./glossary.md)

Typical flow
------------

- Create spec (Jira, roadmap, or manual inputs)
- Validators normalize spec.md and tasks.md
- Execute tasks (all, specific parents, or a single subtask)
- Commit, PR, and optional roadmap update

Tips
----

- Keep `main_idea` to 1–2 sentences; it drives the spec name
- Use `requires_db_changes` and `requires_api_changes` to generate the right sub‑specs
- Check `[spec_folder_path]/tasks.md` to confirm task numbers before targeted runs

External resources
------------------

- Forked from Agent OS website: [buildermethods.com/agent-os](https://buildermethods.com/agent-os)

Extensibility
-------------

- Extend core flows (like create-spec) with optional instruction files—no forking required. Place files under `@~/.agent-os/instructions/extensions/<flow>/` (or project scope at `@.agent-os/...`).
- Use decimal step numbers (e.g., 1.1, 6.2). Core runs first on any collision; extensions are strictly optional.
- See: [Extensions Quickstart](./extensions-quickstart.md) and `instructions/extensions/README.md` for conventions and an example Jira integration.
