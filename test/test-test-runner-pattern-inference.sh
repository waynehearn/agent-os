#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'
pass(){ echo -e "${GREEN}[PASS]${NC} $*"; }
fail(){ echo -e "${RED}[FAIL]${NC} $*"; exit 1; }
info(){ echo -e "${YELLOW}[INFO]${NC} $*"; }

SPEC_DIR="test/.agent-os/specs/2025-08-17-pattern"
rm -rf "$SPEC_DIR" && mkdir -p "$SPEC_DIR/context"

cat > "$SPEC_DIR/tasks.md" <<'MD'
# Tasks

## Task 1: Implement greeting endpoint
- [ ] api test focus
MD

INPUTS_FILE="$SPEC_DIR/inputs.md"
cat > "$INPUTS_FILE" <<MD
@~/.agent-os/instructions/core/execute-tasks.md

[execution_context]
spec_folder_path: $(cd "$SPEC_DIR" && pwd)
[/execution_context]
MD

# No TEST_PATTERN provided; verify inference
TEST_CMD='echo PATTERN="$PATTERN" FILES_HINT="$TEST_FILES_HINT"'
ENABLE_TDD_LOOP=1 TEST_CMD="$TEST_CMD" bash tools/run-execute-task.sh "$INPUTS_FILE" >/dev/null 2>&1 || true

SUMMARY="$SPEC_DIR/context/test-run-summary.json"
[[ -f "$SUMMARY" ]] || fail "Missing test-run-summary.json"

if command -v jq >/dev/null 2>&1; then
  patt=$(jq -r '.pattern' "$SUMMARY")
  files=$(jq -r '.filesHint' "$SUMMARY")
  [[ -n "$patt" && "$patt" != "null" ]] || fail "Expected inferred pattern non-empty"
  [[ -n "$files" && "$files" != "null" ]] || fail "Expected filesHint non-empty"
else
  grep -q '"pattern":"' "$SUMMARY" || fail "Expected pattern in summary"
  grep -q '"filesHint":"' "$SUMMARY" || fail "Expected filesHint in summary"
fi

pass "pattern inference captured in summary"
