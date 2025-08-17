#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'
pass(){ echo -e "${GREEN}[PASS]${NC} $*"; }
fail(){ echo -e "${RED}[FAIL]${NC} $*"; exit 1; }
info(){ echo -e "${YELLOW}[INFO]${NC} $*"; }

SPEC_DIR="test/.agent-os/specs/2025-08-17-test-execute"
INPUTS_FILE="test/test-exec-inputs.md"

rm -rf "$SPEC_DIR"
mkdir -p "$SPEC_DIR/context" "$SPEC_DIR/sub-specs"

cat > "$SPEC_DIR/tasks.md" <<'MD'
# Tasks

## Task 1: Implement greeting endpoint
- [ ] parent checklist

### Subtask 1.1: Add route and controller
- [ ] write failing test
- [ ] implement controller

### Subtask 1.2: Add validation
- [ ] test bad inputs
- [ ] implement schema

## Task 2: Document API
- [ ] parent two
MD

cat > "$INPUTS_FILE" <<'MD'
@~/.agent-os/instructions/core/execute-tasks.md

[execution_context]
spec_folder_path: @.agent-os/specs/2025-08-17-test-execute
[/execution_context]
MD

info "Running execute-tasks script..."
bash tools/execute-tasks.sh "$INPUTS_FILE"

CT_FILE="$SPEC_DIR/context/current-task.md"
TS_FILE="$SPEC_DIR/context/tasks-summary.json"
[[ -f "$CT_FILE" ]] || fail "Missing current-task.md"
[[ -f "$TS_FILE" ]] || fail "Missing tasks-summary.json"
HT_FILE="$SPEC_DIR/context/tasks-heuristics.json"
[[ -f "$HT_FILE" ]] || fail "Missing tasks-heuristics.json"

grep -q "^## Task 1:" "$CT_FILE" && pass "Snippet contains Task 1" || fail "Snippet missing Task 1 header"

if command -v jq >/dev/null 2>&1; then
  num=$(jq -r '.parentTask.number' "$TS_FILE")
  first=$(jq -r '.subtasks.first' "$TS_FILE")
  [[ "$num" == "1" ]] || fail "parentTask.number != 1"
  [[ "$first" == "1.1" ]] || fail "subtasks.first != 1.1"
  pass "Summary JSON validated with jq"
  # Heuristics: Task mentions endpoint/controller/route -> requires_api_changes should be true
  rah=$(jq -r '.requires_api_changes' "$HT_FILE")
  [[ "$rah" == "true" ]] || fail "heuristics.requires_api_changes != true"
  pass "Heuristics JSON validated with jq"
else
  grep -q '"number": 1' "$TS_FILE" || fail "Summary missing number"
  grep -q '"first": "1.1"' "$TS_FILE" || fail "Summary missing first 1.1"
  pass "Summary validated with grep (no jq)"
fi

pass "execute-tasks smoke test completed"
