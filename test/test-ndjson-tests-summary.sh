#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'
pass(){ echo -e "${GREEN}[PASS]${NC} $*"; }
fail(){ echo -e "${RED}[FAIL]${NC} $*"; exit 1; }
info(){ echo -e "${YELLOW}[INFO]${NC} $*"; }

SPEC_DIR="test/.agent-os/specs/2025-08-17-ndjson"
rm -rf "$SPEC_DIR" && mkdir -p "$SPEC_DIR/context"

cat > "$SPEC_DIR/tasks.md" <<'MD'
# Tasks

## Task 1: NDJSON summary emission
- [ ] verify debug trace summary
MD

INPUTS_FILE="$SPEC_DIR/inputs.md"
cat > "$INPUTS_FILE" <<MD
@~/.agent-os/instructions/core/execute-tasks.md

[execution_context]
spec_folder_path: $(cd "$SPEC_DIR" && pwd)
debug_subagents: true
[/execution_context]
MD

# Enable TDD loop so test-runner executes and summary is produced
ENABLE_TDD_LOOP=1 bash tools/run-execute-task.sh "$INPUTS_FILE" >/dev/null 2>&1 || true

TRACE_FILE="$SPEC_DIR/debug/exec-trace/task-1.log"
[[ -f "$TRACE_FILE" ]] || fail "Missing NDJSON trace file: $TRACE_FILE"

# Look for the task-tests-summary action
if ! grep -Fq -- '"action":"task-tests-summary"' "$TRACE_FILE"; then
  info "Trace contents:"; tail -n +1 "$TRACE_FILE" || true
  fail "NDJSON task-tests-summary not found in trace"
fi

pass "NDJSON tests summary present in trace"
