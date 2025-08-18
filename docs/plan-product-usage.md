---
title: Plan Product – Usage and Details
version: 1.0
lastUpdated: 2025-08-16
---

Plan a new product and install Spec Agent K product docs.

Quick links: [Analyze Product](./analyze-product-usage.md) • [Create Spec](./create-spec-usage.md) • [Execute Tasks](./execute-tasks-usage.md)

> Using Jira (extension): Jira is optional and used later during create‑spec. For Jira inputs and comment behavior, see [docs/jira-extension.md](./jira-extension.md).

## Where it fits

- Starting a new repo or greenfield area: run plan‑product first, then create‑spec → execute‑tasks for the first feature.
- Optional for teams that already have strong product docs; beneficial for establishing consistent, AI‑friendly docs and a roadmap used by later flows.

## Basic usage

```text
@~/.agent-os/instructions/core/plan-product.md

[plan_inputs]
main_idea: >
  [1–2 sentence product idea]

key_features:
  - [Feature 1]
  - [Feature 2]
  - [Feature 3]

target_users:
  - [Primary user]

tech_stack_preferences: >
  [Optional preferences: language, framework, db, hosting]

project_initialized: no
[/plan_inputs]
```
## Advanced Features & Debugging
- [Debugging and Execution Trace](./execute-tasks-usage.md#debugging-and-execution-trace)
- [Manifest and Context Management](./manifest-spec.md)
- [Heuristics and Task Validation](./tasks-derivation.md)
- [Troubleshooting](./troubleshooting.md)

## Try it (bash)

These optional bash commands help verify tooling and inspect outputs after you run plan‑product in the editor.

Verify prerequisites and jq:

```bash
bash tools/verify-jq.sh
```

List generated product docs (after plan‑product completes):

```bash
ls -la .agent-os/product
```

Peek at the condensed mission:

```bash
head -n 50 .agent-os/product/mission-lite.md
```

## Run inside Claude Code

Paste the Basic usage block into Claude Code. It reads `@~/.agent-os/instructions/core/plan-product.md` and uses your `[plan_inputs]`.

- Required: `main_idea`, `key_features` (≥3), `target_users` (≥1)
- Optional: `tech_stack_preferences`, `project_initialized`

Claude environment settings (recommended):

- Export `CLAUDE_CODE=1` (or `RUNNING_IN_CLAUDE=1`) in your Claude terminal for this repo.
- Leave pre-LLM context optimization off (`CONTEXT_OPTIMIZE=0` or unset). Subagents will manage chunking/summarization.
- Only force optimization for unusually large docs: set `CONTEXT_OPTIMIZE=1 CONTEXT_OPTIMIZE_FORCE=1 CONTEXT_OPTIMIZE_MODE=lossless CONTEXT_SUMMARIZE_THRESHOLD=2000`.

## What it does (steps)

From `instructions/core/plan-product.md`:

1. Gather user input (with validation and fallbacks for tech stack defaults)
2. Create documentation structure under `.agent-os/product/`
3. Create `mission.md`
4. Create `tech-stack.md` (fill from input/discovery/fallbacks)
5. Create `mission-lite.md` (condensed)
6. Create `roadmap.md` (phases with effort labels)
7. Create `decisions.md` (override‑priority decision log)

## Artifacts produced

- `.agent-os/product/` with:
  - `mission.md`, `mission-lite.md`, `tech-stack.md`, `roadmap.md`, `decisions.md`

## Inputs and flags

- Required: `main_idea`, `key_features` (≥3), `target_users` (≥1)
- Optional: `tech_stack_preferences`, `project_initialized`

## Extensibility and customization

- No dedicated extension loader for this flow.
- Customize by editing the generated docs.
- If you need pre‑population from an external system, run a discovery/sync script before plan‑product and feed the results via inputs.

## Example

```text
@~/.agent-os/instructions/core/plan-product.md

[plan_inputs]
main_idea: >
  Collaborative kanban app for small product teams.
key_features:
  - Swimlanes and WIP limits
  - Real‑time presence
  - Slack notifications
  - API for integrations

target_users:
  - Product and engineering teams

tech_stack_preferences: >
  TypeScript, Next.js, Postgres, Vercel, Fly.io

project_initialized: yes
[/plan_inputs]

## Troubleshooting

- **Missing required fields**: Ensure `main_idea`, at least 3 `key_features`, and at least 1 `target_user` are provided.
- **Validation errors**: Check for typos or formatting issues in the input block.
- **Artifacts not generated**: Verify prerequisites and rerun the workflow; check for errors in the terminal output.

For more help, see [Documentation Standards](./documentation-standards.md) or ask in project discussions.
```
