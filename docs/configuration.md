---
title: Spec Agent K – Configuration
version: 1.0
lastUpdated: 2025-08-14
---

Set up environment, paths, and integrations used by the create-spec and execute-tasks flows.

What this covers
----------------

- Path aliases used in instruction blocks
- Standards and instructions folder locations
- Atlassian MCP (optional) setup notes via extension
- Spec flags that control deterministic outputs
- Editor/tooling assumptions

Path aliases
------------

The docs and examples use logical, normalized paths resolved by the flow:

- `@~/.agent-os/instructions/` – Spec Agent K instruction set (Home folder)
- `@.agent-os/standards/` – Project standards: style, tech stack, best practices (Project folder)
- `@.agent-os/specs/YYYY-MM-DD-<spec-name>/` – Generated spec folder (Project folder)

Tip: Use the `@` prefix exactly as shown in examples; the system resolves these aliases consistently across OS/shells.

Standards & instructions
------------------------

- Ensure your instructions folder exists at `@~/.agent-os/instructions/`
- Ensure project standards exist at `@.agent-os/standards/`
- Optional extension folders:
  - `@~/.agent-os/instructions/extensions/create-spec/` (user/home scope)
  - `@.agent-os/instructions/extensions/create-spec/` (project scope)
  - Place extension files with front matter `targets: ["create-spec"]` to extend the core create-spec flow.
- If your project prefers a different location, add a thin alias/symlink or adapt examples accordingly

Atlassian MCP (optional, via extension)
-------------------

To drive spec creation from Jira tickets, install the Jira extension and configure an Atlassian MCP service in your editor.

- Place `instructions/extensions/create-spec/atlassian-jira.md` in your instructions folder (home or project). It is optional and only loaded if present.
- Pass `jira_issue_key` in `[jira_inputs]` (see [Jira key reference](jira-extension.md#canonical-jira-key-reference))
- Set `use_jira_mcp: true`
- Provide overrides for any missing fields (main_idea, user stories, deliverables, etc.)

Jira sync flags (extension)
---------------

- `post_spec_to_jira: true|false`
  - When true and a valid `jira_issue_key` is provided with MCP available, the extension posts to the Jira issue after creating `spec.md` (see [Jira key reference](jira-extension.md#canonical-jira-key-reference)).
- `jira_comment_mode: summary|diff|full`
  - summary (default): posts a concise change summary on subsequent runs
  - diff: posts a unified diff against the last synced version
  - full: posts full content (or an excerpt if size limits are hit)

Branding/footer
---------------

- Jira comments include a footer for dedupe: `Synced by Spec Agent K • key: <spec_key> • sha256: <hash>`

Auth & connectivity
-------------------

- Use your Atlassian MCP provider’s guidance for authentication (e.g., OAuth or API token)
- Keep credentials out of specs and tasks; rely on your editor’s secrets store or environment

Spec flags (determinism)
------------------------

- `requires_db_changes: true|false`
  - Controls creation of `sub-specs/database-schema.md`
- `requires_api_changes: true|false`
  - Controls creation of `sub-specs/api-spec.md`
- `overwrite_existing: true|false`
  - On file collisions, either ask before overwrite (`false`) or overwrite deterministically (`true`)

Editor/tooling assumptions
--------------------------

- Works with Claude Code, Cursor, or similar AI-enabled editors
- Examples are instruction references, not shell commands; they’re editor-agnostic
- Optional completion chime may not work in all shells; completion banners always print

Shell compatibility
-------------------

- Scripts are portable Bash (POSIX-friendly). Do not run them in PowerShell or cmd.exe.
- On Windows, use Git Bash or WSL Bash. If needed, prefix with `bash` (e.g., `bash ./tools/verify-install.sh`).

Configuration verification
--------------------------

Use the verification tools to sanity‑check your setup and paths:

- Installation and environment (run in Bash): `tools/verify-install.sh`
- jq presence and optional spec manifest check (run in Bash): `tools/verify-jq.sh`

Details and expected output: see Installation → [Verify installation](./installation.md).

Integration tips (project‑specific)
-----------------------------------

- Repository layers and packages
  - When a spec references a specific package (e.g., a NuGet package for the repo layer), set the package ID and version explicitly in your spec inputs to avoid ambiguity

- Database migrations
  - Choose a migration tool consistent with your stack (e.g., EF Core Migrations). Ensure your tasks include creating and applying the migration for new tables

- Git workflow
  - The execute flow can create branches and PRs via a git-workflow subagent; ensure your Git/GitHub auth is configured in your dev environment

Related docs
------------

- Quickstart: [quickstart.md](./quickstart.md)
- Create Spec Usage: [create-spec-usage.md](./create-spec-usage.md)
- Smoke Tests: [smoke-tests.md](./smoke-tests.md)
- Troubleshooting: [troubleshooting.md](./troubleshooting.md)
- Glossary: [glossary.md](./glossary.md)

Caches & manifests (advanced)
-----------------------------

- Extension Registry Cache: front‑matter discovery results are cached for 1 hour in `templates/extension-registry.json`. Cache invalidates when file mtimes or front‑matter hashes change.
- Section‑Aware Manifest: per‑spec `context/manifest.json` tracks hashes and token estimates per section (e.g., `spec.md:overview`) to enable selective reloads.
- Details and schema: see [manifest-spec.md](./manifest-spec.md) and [schemas/manifest.schema.json](./schemas/manifest.schema.json)
