# Implementation Context (Condensed, Restartable)

Last updated: Aug 17, 2025 • Branch: scriptbased-optimized • Default: main • Target shell: Windows Git Bash

## What’s the goal

Keep Phase 2 “Execute Tasks” moving with a token-efficient, script-first workflow that’s cross-platform and restartable from this file alone.

## Copy-paste resume prompt

Copy the block below into your AI IDE when you return to this repo to resume quickly.

```
You are resuming work on Agent OS, Phase 2 (Execute Tasks), with a script-first, token-efficient flow on Windows Git Bash.

Key facts:
- Context gatherer supports hierarchical loading, section hashing, and a shared TTL cache.
- Optional pre-LLM optimization exists (tools/context-optimizer.sh). It auto-disables inside Claude Code unless CONTEXT_OPTIMIZE_FORCE=1.
- New tests cover optimizer, gatherer integration, and Claude auto behavior. Docs updated across usage pages.

Current focus:
- Finalize the tools orphan sweep (remove deprecated stubs if truly unused).
- Keep golden example section hashing green and smoke tests passing.

What to do now:
1) Run smoke: bash test/test-execute-tasks.sh
2) If needed, refresh context for the latest spec:
  LATEST=$(bash tools/context-size.sh | sed -n 's/^LATEST=//p')
  SPEC_DIR=".agent-os/specs/$LATEST"; mkdir -p "$SPEC_DIR/context"
  bash tools/context-gatherer.sh product "$SPEC_DIR/context/product-context.md"
  bash tools/context-gatherer.sh repo "$SPEC_DIR/context/repo-context.md"
3) Optional: enable profiling during runs: ENABLE_PROFILING=1 bash tools/execute-tasks.sh
4) If contexts are large, try optimizer (lossless): set CONTEXT_OPTIMIZE=1 (auto-off in Claude unless forced)

Notes:
- CRLF hardened; logs to stderr to keep outputs clean. Use Git Bash.
- For planning/analysis, route via tools/command-router.sh; product planning uses run-plan-product.sh.
```

## Restart checklist (next step)

- Check latest spec and context size (tokens estimate and freshness):

```bash
bash tools/context-size.sh
```

- If CHARS=0 or context is stale for your needs, refresh minimal context for the latest spec:

```bash
LATEST=$(bash tools/context-size.sh | sed -n 's/^LATEST=//p')
SPEC_DIR=".agent-os/specs/$LATEST"
mkdir -p "$SPEC_DIR/context"
bash tools/context-gatherer.sh product "$SPEC_DIR/context/product-context.md"
bash tools/context-gatherer.sh repo "$SPEC_DIR/context/repo-context.md"
```

- Resume execution: pick one
- Quick smoke (validates core artifacts and manifest refresh):

```bash
bash test/test-execute-tasks.sh
```

- Per-parent runner with optional TDD loop (set your test command):

```bash
ENABLE_TDD_LOOP=1 TEST_CMD="npm test --silent" TEST_RETRIES=1 bash tools/run-execute-task.sh
```

Notes

- Windows Git Bash is supported; scripts are CRLF-hardened.
- You can enable profiling to capture context size and timing:

```bash
ENABLE_PROFILING=1 bash tools/execute-tasks.sh
```

## Single plan list — Done vs. Outstanding

- [x] Execute main loop writes artifacts and refreshes manifest
  - tools/execute-tasks.sh writes: context/current-task.md, context/tasks-summary.json, context/tasks-heuristics.json; refreshes context/manifest.json for tasks.md
- [x] Per-parent runner selective-reading + gates + debug trace
  - tools/run-execute-task.sh extracts selected-technical.md, selected-api.md (gated), selected-db.md (gated); emits NDJSON trace when debug_subagents=true
- [x] Optional TDD loop + focused tests + retries
  - tools/test-runner.sh supports TEST_CMD, TEST_PATTERN (inferred), TEST_RETRIES; summary at context/test-run-summary.json
- [x] NDJSON test summary emission (per parent task)
- [x] Golden example section hashing across sub-specs
  - examples/golden/sub-specs/{api-spec.md,database-schema.md} included; section-hash updates context/manifest.json
- [x] CRLF hardening (Windows Git Bash)
  - Normalization in execute scripts and context gatherers to avoid \r drift; verified by test/test-crlf-portability.sh
- [x] Context gatherers: hierarchical loading + section hashing
  - tools/context-gatherer*.sh with CRLF-safe extraction and hashing
- [x] Docs aligned for Execute Tasks (usage + artifacts)
  - commands/execute-tasks.md, docs/execute-tasks-usage.md updated earlier
- [x] Tests added and passing
  - test/test-execute-tasks.sh (smoke), test/test-run-execute-task.sh (selective reading), test/test-test-runner-retries.sh, test/test-test-runner-pattern-inference.sh, test/test-ndjson-tests-summary.sh, test/test-crlf-portability.sh
- [ ] Pattern-to-glob mapping: improve inference to common frameworks (Jest, Mocha, PyTest, JUnit)
- [x] Shared context cache with TTL + dedup across commands
- [x] Front-matter-only extension scanning
- [x] Extension discovery + compatibility checks + paths
- [x] Execute extension steps at numeric boundaries during create-spec run
- [ ] CI bundle for cross-platform test runs (local mini-CI script acceptable as first step)
- [ ] Advanced context optimizations (compression, semantic chunking, summarization)
  - [x] Add portable optimizer tool: tools/context-optimizer.sh (chunking, lossless compression, heuristic summarization, CRLF-safe)
  - [x] Add smoke test: test/test-context-optimizer.sh
  - [x] Wire into context gatherer (optional pre-LLM pass)
  - [x] Auto-disable in Claude Code unless forced (CLAUDE_CODE=1 auto-disables; CONTEXT_OPTIMIZE_FORCE=1 overrides)
  - [ ] Add budget-aware integration using tasks-heuristics.json
  - [x] Document configuration flags and defaults

## Resume the current task (orphan sweep)

Copy this prompt to rehydrate context and continue the orphan cleanup safely.

```
You are resuming the "tools orphan sweep" task in Agent OS (branch: scriptbased-optimized, shell: Windows Git Bash).

Goals:
- Confirm no remaining references to deprecated scripts:
  tools/plan-product.sh, tools/discover-product-context-simple.sh,
  tools/analyze-product.sh, tools/script-template.sh.
- If zero references outside tools/, remove these stubs and update Today’s delta.
- Re-run golden section hash and core smoke tests.

Steps:
1) Search for any references (ignore hits inside tools/ for the file itself):
  git grep -nE "tools/(plan-product\\.sh|discover-product-context-simple\\.sh|analyze-product\\.sh|script-template\\.sh)" || true

2) If no references found outside tools/, delete the stubs:
  git rm tools/plan-product.sh tools/discover-product-context-simple.sh tools/analyze-product.sh tools/script-template.sh

3) Update docs/implementation-context.md "Today’s delta" to mark orphan sweep finalized.

4) Verify:
  bash tools/section-hash.sh "c:/Users/Wayne.Hearn/data/code/github/myagentos/examples/golden"
  bash test/test-execute-tasks.sh

Notes:
- Use Windows Git Bash. Don’t alter run-* entry points or command-router.
- If any reference appears in docs, replace with run-* equivalents, commit, and retry.
```

## How to resume (quick-run)

1) Execute Tasks smoke (validates snippet, summary, heuristics, manifest)

```bash
bash test/test-execute-tasks.sh
```

2) Per-parent runner with optional TDD loop

Environment flags:

- ENABLE_TDD_LOOP=1 to invoke tests
- TEST_CMD: your test command
- TEST_PATTERN: focus pattern (auto-inferred from parent title if not set)
- TEST_RETRIES: retry count (default 1)

Expected artifacts per parent spec folder:

- context/current-task.md, context/tasks-summary.json, context/tasks-heuristics.json
- context/selected-technical.md, context/selected-api.md (if gated), context/selected-db.md (if gated)
- context/test-run-summary.json (when TDD flag is enabled)

3) Golden example section hashing (verifies section-level manifest across sub-specs)

```bash
bash tools/section-hash.sh "c:/Users/Wayne.Hearn/data/code/github/myagentos/examples/golden"
```

## Technical directives (do not skip)

- Line endings: CRLF-safe always
  - All markdown section extraction and hashing remove \r before matching/hashing (execute scripts and context gatherers)
  - Keep using awk-based block extraction and grep -Fq -- for literal matches; avoid \b word boundaries in portable grep
- Heuristics gates for API/DB selective-reading
  - Decide based on context/tasks-heuristics.json plus current-task snippet scan
- Debug tracing
  - When debug_subagents=true, emit NDJSON lines (e.g., action: task-tests-summary) from tools/run-execute-task.sh
- Profiling (optional)
  - ENABLE_PROFILING=1 toggles ce_track_file hooks where present

## Minimal run recipes

- Analyze (non-destructive; honors discovery’s write-if-missing):

```bash
bash tools/run-analyze-product.sh --output-dir docs/analysis6 analyze-inputs.md
```

- Focused TDD for a parent task (example):

```bash
ENABLE_TDD_LOOP=1 TEST_CMD="npm test --silent" TEST_RETRIES=1 bash tools/run-execute-task.sh
```

## Quick verification suite

Run high-value checks after changes:

- CRLF portability: `bash test/test-crlf-portability.sh`
- Retries behavior: `bash test/test-test-runner-retries.sh`
- Selective reading: `bash test/test-run-execute-task.sh`
- Smoke: `bash test/test-execute-tasks.sh`
- Golden hashing: run section-hash.sh (see above)
- Context optimizer: `bash test/test-context-optimizer.sh`
- Claude auto-behavior: `bash test/test-context-gatherer-claude-auto-disable.sh` and `bash test/test-context-gatherer-claude-force-override.sh`

## Notes and artifacts

- Section manifests: context/manifest.json per spec folder contains files + sections (+ hashes)
- Test summaries: context/test-run-summary.json records attempts, duration, pattern, filesHint
- NDJSON traces: debug/exec-trace/task-<n>.log when enabled
- Optimized contexts: when enabled, `tools/context-optimizer.sh` can produce a `.meta.json` with per-chunk actions and token deltas.

### Optional: Pre-LLM optimization

To reduce tokens for large contexts before sending to the LLM, you can run:

```bash
bash tools/context-optimizer.sh \
  --input ".agent-os/specs/$LATEST/context/repo-context.md" \
  --output ".agent-os/specs/$LATEST/context/repo-context.optimized.md" \
  --metadata-out ".agent-os/specs/$LATEST/context/repo-context.optimized.meta.json" \
  --compression lossless \
  --summarize-threshold 800
```

### Auto behavior and configuration

- Default: CONTEXT_OPTIMIZE=0 (off). Enable with CONTEXT_OPTIMIZE=1.
- In Claude Code: set CLAUDE_CODE=1 (or RUNNING_IN_CLAUDE=1). Optimization auto-disables unless forced.
- Force override: CONTEXT_OPTIMIZE_FORCE=1 (use with care; prefer lossless mode and high thresholds to avoid double-summarization).
- Tuning:
  - CONTEXT_OPTIMIZE_MODE=lossless|aggressive|none (default lossless)
  - CONTEXT_SUMMARIZE_THRESHOLD=800 (increase in subagent environments)
  - CONTEXT_MAX_CHUNK_TOKENS=500

## Today’s delta (Aug 17, 2025)

- CRLF normalization added to context gatherers (simple/with-sections/full) and to hashing paths; validated with smoke test.
- Golden examples section-hash still green; manifest updates confirmed.
- Retries and pattern inference tests rerun; all pass on Windows Git Bash.

- Shared TTL cache integrated into context gatherer (tools/context-gatherer.sh):
  - Flags: --no-cache, --use-cache (default on), --cache-ttl <seconds>; env: USE_CACHE, OPERATION_CACHE_TTL
  - Uses context-cache-manager for TTL + content-hash validation; cache hit short-circuits gather

- Front-matter-only extension scanning implemented:
  - New tool: `tools/extensions/extension-scanner.sh` reads only YAML front matter to filter by `targets` and `requires`.
  - Flags: `--flow`, `--scope home|project|repo|all|none`, `--capabilities`, `--no-cache`, `--cache-ttl`, `--extra-root`, `--debug-lines`.
  - Integrates with shared TTL cache; emits JSON with `loaded`/`skipped` arrays and reasons.
  - Minimal test added: `test/test-extension-scanner.sh` (validates capability gating via temp roots).
  - Docs updated: `docs/extensions-quickstart.md` (scanner usage), `docs/shared-context-management.md` (registry note).
  - Integrated into create-spec Step 0.9 (debug report): `tools/run-create-spec.sh` now emits an Extensions Discovery Report when `debug_extensions: true` or `DEBUG_EXTENSIONS=1`.
    - Honors `RUNTIME_CAPABILITIES`, `EXTENSIONS_ENABLED`, `EXTENSION_SCOPE`, `EXTENSION_EXTRA_ROOTS`.
    - Includes a "Merged step order (preview)" combining core and loaded extension steps.
    - Performance: reduced to a single scanner call by capturing stdout (JSON) and stderr (human lines) concurrently.
    - Usage doc updated: `docs/create-spec-usage.md` section “Extensions discovery (debug)”.
  - Extension steps now execute during the run at numeric boundaries (placeholders logged per step); honored env: `EXTENSIONS_ENABLED`, `EXTENSION_SCOPE`, `RUNTIME_CAPABILITIES`, `EXTENSION_EXTRA_ROOTS`. Usage doc updated with a new "Runtime: Extension step execution" section.

- Tools audit and cleanup:
  - Orphan sweep finalized: All deprecated scripts (`tools/discover-product-context-simple.sh`, `tools/plan-product.sh`, `tools/script-template.sh`, `tools/analyze-product.sh`) removed from the repo after confirming no remaining references outside docs/ and tools/.
  - Use `tools/run-plan-product.sh` for product planning via `tools/command-router.sh`.

- Advanced context optimization pass integrated and documented:
  - `tools/context-optimizer.sh` wired into `tools/context-gatherer.sh` (optional, pre-LLM).
  - Claude-aware auto-disable in place; `CONTEXT_OPTIMIZE_FORCE=1` override available.
  - Configuration flags and defaults documented in this file; tests added to verification suite.

---

With the above, you can pick up Phase 2 immediately: run the smoke test, opt into the TDD loop as needed, and implement the outstanding items (pattern-to-glob mapping, shared cache, CI script) in small increments.
