#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'
pass(){ echo -e "${GREEN}[PASS]${NC} $*"; }
fail(){ echo -e "${RED}[FAIL]${NC} $*"; exit 1; }
info(){ echo -e "${YELLOW}[INFO]${NC} $*"; }

SPEC_DIR="test/.agent-os/specs/2025-08-17-retry"
rm -rf "$SPEC_DIR" && mkdir -p "$SPEC_DIR/context" "$SPEC_DIR/sub-specs"
FULL_SPEC_DIR=$(cd "$SPEC_DIR" && pwd)

# Minimal tasks.md so run-execute-task can operate
cat > "$SPEC_DIR/tasks.md" <<'MD'
# Tasks

## Task 1: Validate retry path
- [ ] Ensure retry works

### Subtask 1.1: First
Do something.
MD

# Fake command: fail first run (marker absent), then succeed
MARKER="$SPEC_DIR/context/.marker"
TEST_CMD='if [ -f '"$MARKER"' ]; then exit 0; else echo first run fails >&2; touch '"$MARKER"'; exit 1; fi'

INPUTS_FILE="$SPEC_DIR/inputs.md"
cat > "$INPUTS_FILE" <<MD
@~/.agent-os/instructions/core/execute-tasks.md

[execution_context]
spec_folder_path: $FULL_SPEC_DIR
[/execution_context]
MD

info "Running test-runner with retries=1..."
if ENABLE_TDD_LOOP=1 TEST_CMD="$TEST_CMD" TEST_RETRIES=1 bash tools/run-execute-task.sh "$INPUTS_FILE" ; then
  :
else
  fail "run-execute-task returned non-zero despite retry"
fi

SUMMARY="$SPEC_DIR/context/test-run-summary.json"
[[ -f "$SUMMARY" ]] || fail "Missing test-run-summary.json"

if command -v jq >/dev/null 2>&1; then
  succ=$(jq -r '.success' "$SUMMARY")
  attempts=$(jq -r '.attempts' "$SUMMARY")
  [[ "$succ" == "true" ]] || fail "Expected success after retry"
  [[ "$attempts" -ge 2 ]] || fail "Expected attempts >= 2, got $attempts"
else
  grep -q '"success":true' "$SUMMARY" || fail "Expected success in summary"
fi

pass "test-runner retries behavior validated"
