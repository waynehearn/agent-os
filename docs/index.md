---
title: Spec Agent K – Start here
version: 1.0
lastUpdated: 2025-08-14
---

Welcome
-------

Spec Agent K is your system for spec‑driven agentic development. It gives AI coding agents structured workflows aligned to your standards, stack, and codebase context so they ship quality code on the first try—not the fifth.

Navigation
----------

- Usage guide: [create-spec-usage.md](./create-spec-usage.md)
- Create-spec steps: [create-spec-steps.md](./create-spec-steps.md)
- Architecture & customization: [architecture.md](./architecture.md)
- Manifest spec: [manifest-spec.md](./manifest-spec.md)
- Section hashing: [section-hashing.md](./section-hashing.md)
- Schemas: [schemas/](./schemas/)
- Task creation details: [create-spec-tasks.md](./create-spec-tasks.md)
- How modes/settings shape tasks: [tasks-derivation.md](./tasks-derivation.md)
- Installation: [installation.md](./installation.md)
- Copilot usage (GitHub Copilot Chat): [copilot-usage.md](./copilot-usage.md)
- Configuration: [configuration.md](./configuration.md)
- Extensions QuickStart: [extensions-quickstart.md](./extensions-quickstart.md)
- [jira-extension.md](./jira-extension.md) (optional)
- Task ordering hints: [task-organization-hints.md](./task-organization-hints.md)
- QuickStart: [quickstart.md](QuickStart%20Guide.md)
- Smoke tests: [smoke-tests.md](./smoke-tests.md)
- Troubleshooting: [troubleshooting.md](./troubleshooting.md)
- Glossary: [glossary.md](./glossary.md)

Typical flow
------------

- Create spec (From Jira, roadmap, or manual inputs)
- Validators normalize spec.md and tasks.md
- Execute tasks (all, specific parents, or a single subtask)
- Commit, PR, and optional roadmap update

Determinism & context policy
----------------------------

- Lite-first reads: prefer `spec-lite.md`, `context/facts.md`, and manifest hashes
- Section-level manifest enables targeted reloads and 4k-token budget awareness
- Extension registry caching uses front-matter-only reads; unsupported capabilities are safely skipped

Tips
----

- Keep `main_idea` to 1–2 sentences; it drives the spec name
- Use `requires_db_changes` and `requires_api_changes` to generate the right sub‑specs
- Check `[spec_folder_path]/tasks.md` to confirm task numbers before targeted runs

Extensibility
-------------

- Extend core flows (like create-spec) with optional instruction files—no forking required. Place files under `@~/.agent-os/instructions/extensions/<flow>/` (or project scope at `@.agent-os/...`).
- Use decimal step numbers (e.g., 1.1, 6.2). Core runs first on any collision; extensions are strictly optional.
- See: [Extensions Quickstart](./extensions-quickstart.md) and `instructions/extensions/README.md` for conventions and an example Jira integration.

External resources
------------------

- Forked from Agent OS website: [buildermethods.com/agent-os](https://buildermethods.com/agent-os)
