---
title: Product Context Discovery
version: 1.0
lastUpdated: 2025-08-16
---

Overview
--------

This document describes the Bash-only product context discovery used by Spec Agent K flows to avoid duplicating context across tools like Claude Code, Serena MCP, and repository docs.

Goals
-----

- Prefer existing, authoritative sources
- Be fast and side-effect free by default
- Only create product docs if nothing sufficient exists

Discovery order
---------------

1. Explicit `--source-file` (highest precedence)
2. `.agent-os/product/context/context.json` (cache)
3. `CLAUDE.md` → "Project Overview" section
4. Adaptive fuzzy discovery of likely technical docs (docs/, design/, architecture/, spec/, specs/, root)
5. `.agent-os/product/` docs: `mission.md`, `tech-stack.md`, `roadmap.md`, `decisions.md`, `context/facts.md`
6. `docs/architecture.md`, `docs/index.md`
7. `README.md` (top paragraphs)
8. Heuristics from build/config files (`package.json`, `pyproject.toml`, `Gemfile`, `pom.xml`, `build.gradle*`, `go.mod`, `Cargo.toml`, `composer.json`, `*.csproj`)

Output shape
------------

JSON Schema: `docs/schemas/product-context.schema.json`.

CLI usage
---------

Run from project root:

```bash
bash tools/discover-product-context.sh --write-if-missing

# Prefer a specific source document
bash tools/discover-product-context.sh --source-file ./CLAUDE.md --write-if-missing

```

Options:

- `--write`: persist to `.agent-os/product/context/context.json`
- `--write-if-missing`: only write if cache file is absent
- `--init-product`: if context is insufficient, create minimal `.agent-os/product/` skeleton and a lite `context/facts.md`
- `--source-file PATH`: treat PATH as the primary source of technical specs (Markdown/text)

Integration notes
-----------------

- `analyze-product` calls discovery first; it only creates `.agent-os/product/` if discovery reports insufficient context.
- Other flows (create-spec, execute-tasks) can consult the cache for tech stack and overview, but remain independent.

Windows


## Troubleshooting

- **Missing context output**: Ensure you ran the script from the project root and used the correct flags (`--write`, `--write-if-missing`).
- **Cache not written**: Check file permissions and verify the target directory exists.
- **Source file not found**: Confirm the path to your source file is correct and accessible.
- **Discovery order issues**: Review the discovery order above and ensure your authoritative docs are in expected locations.

For more help, see [troubleshooting.md](./troubleshooting.md) or ask in project discussions.
Use Git Bash or WSL. PowerShell is not required for discovery.
