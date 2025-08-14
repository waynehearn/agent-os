---
description: Common Pre-Flight Steps for Spec Agent Kibo Instructions
globs:
alwaysApply: false
version: 1.0
encoding: UTF-8
---

# Pre-Flight Rules

- IMPORTANT: For any step that specifies a subagent in the subagent="" XML attribute you MUST use the specified subagent to perform the instructions for that step.

- Process XML blocks sequentially

- Use exact templates as provided

- Lite-first context policy:
  - Prefer condensed sources (mission-lite.md, spec-lite.md, context/facts.md) and task-scoped snippets over full documents.
  - Maintain and consult [spec_folder_path]/context/manifest.json when available:
    - If a file's sha256 matches the last recorded value, skip re-loading it.
    - When loading, prefer section-scoped reads; avoid full-file loads unless explicitly required.
  - Strict do-not-load during execution: decisions.md and full mission.md (load roadmap.md only when a preliminary check requires it).

## Tool prerequisite

- jq must be available in PATH for helper scripts and manifest updates. See docs/installation.md for platform-specific install steps.
