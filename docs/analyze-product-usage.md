---
title: Analyze Product – Usage and Details
version: 1.0
lastUpdated: 2025-08-16
---

Analyze an existing codebase and install Spec Agent K product docs with a discovery‑first approach.

## Where it fits

- New project: run plan‑product first. Existing project: run analyze‑product to derive product docs from code, then continue with create‑spec → execute‑tasks.
- Optional but recommended for existing repos. Benefits: accurate, code‑aligned product docs, cached context for later flows, less back‑and‑forth when creating specs.

## Basic usage

```text
@~/.agent-os/instructions/core/analyze-product.md

[analyze_inputs]
context_notes: >
  [Optional: key notes to guide analysis]
auto_init_product: false
[/analyze_inputs]
```

Tip: You can pre‑run discovery to populate a cache without creating docs:

```bash
bash tools/discover-product-context.sh --write-if-missing
```

## Try it (bash)

These are optional bash commands (Git Bash on Windows, or any Unix shell). No PowerShell required.

Verify prerequisites and jq:

```bash
bash tools/verify-jq.sh
```

Run discovery (read-only if cache exists):

```bash
bash tools/discover-product-context.sh --write-if-missing
```

Inspect the discovery cache if created:

```bash
jq . .agent-os/product/context/context.json
```

Bootstrap minimal product docs with discovered content only (opt-in; no placeholders):

```bash
bash tools/discover-product-context.sh --init-product --write
```

Then open your editor and paste the Basic usage block into a new message to run analyze‑product.

## What it does (steps)

From `instructions/core/analyze-product.md`:

1. Analyze existing codebase
   - Project structure, tech stack, implementation progress, coding patterns.
2. Gather product context (discovery‑first)
   - Runs `tools/discover-product-context.sh --write-if-missing`.
   - Uses context‑fetcher to fill gaps with targeted questions.
3. Execute plan‑product with context
   - Passes the derived inputs to plan‑product to create standard docs.
4. Customize generated files
   - Adjust roadmap (Phase 0 for done work), verify stack, document decisions.
5. Final verification & summary
   - Confirms installation and provides next steps.

## Artifacts produced

- `.agent-os/product/`
   - From analyze-product (via plan-product): `mission.md`, `mission-lite.md`, `tech-stack.md`, `roadmap.md`, `decisions.md`
   - From discovery `--init-product` (only if content exists): subset of `tech-stack.md`, `roadmap.md`, `decisions.md`, and `context/facts.md`
- `.agent-os/product/context/context.json` (discovery cache, only if missing)

## Inputs and flags

- `context_notes` (optional): high‑level guidance for analysis.
- `auto_init_product` (optional): when true, discovery may bootstrap minimal product docs if none exist.

## Extensibility and customization

- No dedicated extension loader for this flow. Customize by:
  - Editing the generated product docs (roadmap, tech‑stack, decisions).
  - Re‑running analyze‑product after substantial code changes to refresh context.
  - Using your own discovery scripts before step 2 (keep outputs under `.agent-os/product/context/`).

## Example

```text
@~/.agent-os/instructions/core/analyze-product.md

[analyze_inputs]
context_notes: >
  Existing Rails + React monolith; DB is Postgres; major features: auth, reporting.
auto_init_product: true
[/analyze_inputs]
```
