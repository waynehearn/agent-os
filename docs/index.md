---
title: Spec Agent K – Start here
version: 1.0
lastUpdated: 2025-08-14
---


Welcome
-------

Spec Agent K is your system for spec‑driven agentic development. It gives AI coding agents structured workflows aligned to your standards, stack, and codebase context so they ship quality code on the first try—not the fifth.

---

## Documentation Table of Contents

### Getting Started

- [QuickStart Guide](../QuickStart%20Guide.md)
- [Installation](./installation.md)
- [Glossary](./glossary.md)

### Core Concepts

- [Context Discovery](./context-discovery.md)
- [Context Profiling](./context-profiling.md)
- [Context Gatherer Implementation](./context-gatherer-implementation.md)
- [Context Gatherer Enhancement](./context-gatherer-enhancement.md)
- [Command Router Implementation](./command-router-implementation.md)
- [Command Router Enhancement Summary](./command-router-enhancement-summary.md)

### Usage & Workflows

- [Analyze Product – Usage](./analyze-product-usage.md)
- [Plan Product – Usage](./plan-product-usage.md)
- [Create Spec – Usage](./create-spec-usage.md)
- [Create Spec Steps](./create-spec-steps.md)
- [Create Spec Tasks](./create-spec-tasks.md)
- [Create Spec Script Plan](./create-spec-script-plan.md)
- [Execute Tasks – Usage](./execute-tasks-usage.md)
- [Copilot Usage](./copilot-usage.md)
- [Running Without Claude Code](./running-without-claude-code.md)

### Features & Extensions

- [Section Hashing](./section-hashing.md)
- [Context Optimization](./llm-context-optimization.md)
- [Extensions QuickStart](./extensions-quickstart.md)
- [Shared Context Management](./shared-context-management.md)
- [Jira Extension](./jira-extension.md)
- [Jira Token Efficiency](./jira-token-efficiency.md)
- [Optional Jira Integration Design](./optional-jira-integration-design.md)

### Reference & Advanced

- [Configuration](./configuration.md)
- [Manifest Spec](./manifest-spec.md)
- [Documentation Standards](./documentation-standards.md)
- [Troubleshooting](./troubleshooting.md)
- [Schemas](./schemas/README.md)
- [Smoke Tests](./smoke-tests.md)
- [Task Organization Hints](./task-organization-hints.md)
- [Tasks Derivation](./tasks-derivation.md)
- [Token Efficiency Doc Update](./token-efficiency-doc-update.md)
- [Token Efficiency User Guide](./token-efficiency-user-guide.md)
- [Token Efficient Hybrid Approach](./token-efficient-hybrid-approach.md)
- [Roadmap](../roadmap.md)
- [Changelog](../CHANGELOG.md)

---

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
