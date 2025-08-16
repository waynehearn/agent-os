# Improvement Plan: Create-spec prompting system

This plan addresses the identified gaps in the prompting system that converts brief enhancement requests into functional software specifications and task plans.

## Objectives

- Eliminate ambiguity in subagent behavior and extension ordering.
- Centralize schemas and constants to prevent drift.
- Introduce controlled flexibility for scope/deliverable counts and backend work.
- Document manifest mechanics and improve task prioritization and categorization.
- Smooth automation via non-interactive mode and enrich examples/troubleshooting.

## Timeline (3 sprints)

- Sprint 1 (weeks 1–2): Contracts, Schemas, Merge precedence, Jira naming.
- Sprint 2 (weeks 3–4): Strictness config, Deliverable framing, Manifest spec.
- Sprint 3 (weeks 5–6): Prioritization heuristics, Category inference hints, Non-interactive mode, Golden examples and troubleshooting.

## Workstreams and tasks

### 1) Subagent contracts

- Goal: Formalize inputs/outputs, error modes, and side effects for subagents used in the flow (context-fetcher, date-checker, validators).
- Changes:
  - New: `docs/agents/contracts.md` (per-agent sections; IO contract, errors, retries, idempotency).
  - Update cross-references in `docs/index.md` and relevant agent docs under `claude-code/agents/`.
- Success criteria: Each referenced agent has a contract section; validators list all guarantees; one-page summary linked from `docs/index.md`.

### 2) Centralized schemas and constants

- Goal: Single source of truth for spec inputs, spec.md structure, tasks.md structure, and manifest schema.
- Changes:
  - New: `docs/schemas/spec-input.schema.json` (JSON Schema), `docs/schemas/spec-md.schema.md`, `docs/schemas/tasks-md.schema.md`, `docs/schemas/manifest.schema.json`.
  - Update references in `instructions/core/create-spec.md`, `commands/create-spec.md`, and `docs/create-spec-usage.md` to point to these.
- Success criteria: Lint pass for all references; no duplicate shape definitions remain in the docs.

### 3) Extension merge precedence

- Goal: Deterministic ordering for multiple extensions targeting the same step.
- Changes:
  - New: `docs/extensions/merge-rules.md` documenting precedence: core < extension priority (0–100) < extension id (lexicographic).
  - Update: `docs/extensions-quickstart.md` and `instructions/extensions/README.md` to include tie-break rules and how to declare `priority`.
  - Update: `instructions/core/create-spec.md` to show ordering in the Discovery Report.
- Success criteria: Example Discovery Report includes resolved ordering; docs include at least two-extension tie example.

### 4) Jira key naming consistency

- Goal: Align key names across all Jira-related docs and examples.
- Changes:
  - Source of truth: `docs/jira-extension.md` key list.
  - Update: `docs/create-spec-usage.md` and `instructions/extensions/create-spec/atlassian-jira.md` examples to match.
- Success criteria: No mismatches in key names; one-table summary appears in all three docs.

### 5) Configurable strictness for counts

- Goal: Allow controlled relaxation of story/scope/deliverable counts.
- Changes:
  - New config flag: `strict_counts: true|false` (default: true) documented in `docs/create-spec-usage.md`.
  - Update: `instructions/core/spec-validator.md` and `instructions/core/tasks-validator.md` to honor the flag deterministically.
- Success criteria: Smoke tests show both strict and relaxed paths yield valid, deterministic outputs.

### 6) Broaden deliverable framing

- Goal: Support backend/platform work by generalizing deliverable verification.
- Changes:
  - Update: Step 6 in `instructions/core/create-spec.md` to replace “browser-testable” with “externally verifiable acceptance outcomes,” with examples (e.g., CLI output, API contract, log-based assertion).
  - Update: `docs/create-spec-usage.md` to include backend examples.
- Success criteria: Backend-only example produces compliant deliverables without exceptions.

### 7) Manifest mechanics specification

- Goal: Make hashing/manifest behavior explicit and reproducible.
- Changes:
  - New: `docs/manifest-spec.md` (fields, sha256 algorithm, update rules, conflict resolution).
  - Update: Link from `instructions/core/create-spec.md`, `docs/create-spec-steps.md`, and `instructions/core/execute-task.md`.
- Success criteria: Example manifest validates against `manifest.schema.json`; end-to-end doc references are consistent.

### 8) Roadmap-driven prioritization heuristics

- Goal: Provide simple, transparent ranking of next tasks.
- Changes:
  - New: `docs/prioritization-heuristics.md` (effort, value, dependency count scoring; tie-breakers and user confirmation step).
  - Update: Step 1 in `instructions/core/create-spec.md` and `docs/create-spec-usage.md` to present top-N candidates before selection.
- Success criteria: Heuristic applied in examples; user confirmation step documented.

### 9) Stronger task category inference

- Goal: Reduce misclassification via project-local hints.
- Changes:
  - New optional hints file: `docs/task-category-hints.md` and support doc describing `spec_folder_path/context/category-hints.json` (regex/synonyms).
  - Update: `docs/task-organization-hints.md` and `instructions/extensions/create-spec/task-organization-hints.md` to reference hints.
- Success criteria: Example with custom hints reclassifies at least one task correctly vs. baseline.

### 10) Non-interactive mode

- Goal: Enable CI-style runs without prompts.
- Changes:
  - New flag: `non_interactive: true` documented in `docs/create-spec-usage.md`.
  - Update: `instructions/core/create-spec.md` to bypass prompts with deterministic defaults; note override precedence.
- Success criteria: Smoke test demonstrates full run without user input; logs show default decisions.

### 11) Troubleshooting and golden examples

- Goal: Improve debuggability and provide canonical outputs.
- Changes:
  - New: `examples/golden/spec.md` and `examples/golden/tasks.md` (well-annotated), linked from `docs/smoke-tests.md` and `docs/create-spec-steps.md`.
  - Update: `docs/troubleshooting.md` with a new section for common validation failures and remedies.
- Success criteria: Golden examples referenced in docs; troubleshooting entries cover at least 5 common issues.

## Acceptance and quality gates

- Docs build/lint: No broken links; references updated where specified.
- Schema validation: JSON Schemas load and validate provided examples.
- Smoke tests: Strict vs relaxed counts; interactive vs non-interactive; backend deliverables path.
- Determinism: Same inputs yield identical outputs across two runs (hashes match where applicable).

## Risks and mitigations

- Drift risk during migration to centralized schemas → Mitigate with a one-pass find-and-replace PR and link checking.
- Over-configuration complexity → Keep new flags minimal and well-documented defaults.
- Extension precedence confusion → Provide worked examples and Discovery Report snapshot.

## Ownership and tracking

- Propose owners: Core prompting flows (Create-spec), Extensions (Jira, task-organization), Docs/Examples.
- Create one tracking issue per workstream and one umbrella epic; link to this plan.
