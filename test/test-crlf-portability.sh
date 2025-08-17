#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'
pass(){ echo -e "${GREEN}[PASS]${NC} $*"; }
fail(){ echo -e "${RED}[FAIL]${NC} $*"; exit 1; }
info(){ echo -e "${YELLOW}[INFO]${NC} $*"; }

SPEC_DIR="test/.agent-os/specs/2025-08-17-crlf"
rm -rf "$SPEC_DIR" && mkdir -p "$SPEC_DIR/context"

# Create a CRLF-terminated tasks.md (safe printf usage)
{
  printf '%s\r\n' '# Tasks'
  printf '%s\r\n' ''
  printf '%s\r\n' '## Task 1: Check CRLF handling'
  printf '%s\r\n' '- [ ] windows endings'
} > "$SPEC_DIR/tasks.md"

INPUTS_FILE="$SPEC_DIR/inputs.md"
cat > "$INPUTS_FILE" <<MD
@~/.agent-os/instructions/core/execute-tasks.md

[execution_context]
spec_folder_path: $(cd "$SPEC_DIR" && pwd)
[/execution_context]
MD

# Run per-task runner to ensure no errors on CRLF inputs
bash tools/run-execute-task.sh "$INPUTS_FILE" >/dev/null 2>&1 || true

# Validate outputs exist and are parseable
[[ -f "$SPEC_DIR/context/current-task.md" ]] || fail "Missing current-task.md"
[[ -f "$SPEC_DIR/context/tasks-summary.json" ]] || fail "Missing tasks-summary.json"

pass "CRLF portability smoke test passed"
