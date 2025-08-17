#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'
pass(){ echo -e "${GREEN}[PASS]${NC} $*"; }
fail(){ echo -e "${RED}[FAIL]${NC} $*"; exit 1; }
info(){ echo -e "${YELLOW}[INFO]${NC} $*"; }

SPEC_DIR="test/.agent-os/specs/2025-08-17-test-run-exec"
INPUTS_FILE="test/test-run-exec-inputs.md"

rm -rf "$SPEC_DIR"
mkdir -p "$SPEC_DIR/context" "$SPEC_DIR/sub-specs" "$SPEC_DIR/debug/exec-trace"

cat > "$SPEC_DIR/tasks.md" <<'MD'
# Tasks

## Task 1: Greeting API feature
- [ ] parent checklist

### Subtask 1.1: Add API route and controller
- [ ] write failing test
- [ ] implement controller

### Subtask 1.2: Persist greeting to DB schema
- [ ] add migration
- [ ] update repository
MD

cat > "$SPEC_DIR/sub-specs/technical-spec.md" <<'MD'
# Technical Spec

## Greeting API feature
Implementation approach for the Greeting API feature, including router and controller wiring.

## Unrelated section
This should not be selected.
MD

cat > "$SPEC_DIR/sub-specs/api-spec.md" <<'MD'
# API Spec

## Greeting API feature
GET /api/greeting -> 200 OK { message: string }
POST /api/greeting -> 201 Created
MD

cat > "$SPEC_DIR/sub-specs/database-schema.md" <<'MD'
# Database Schema

## Greeting API feature
Table: greetings (id PK, message TEXT)
Migration: V20250817__add_greetings.sql
MD

cat > "$INPUTS_FILE" <<'MD'
@~/.agent-os/instructions/core/execute-tasks.md

[execution_context]
spec_folder_path: @.agent-os/specs/2025-08-17-test-run-exec
debug_subagents: true
[/execution_context]
MD

info "Priming heuristics via execute-tasks to generate tasks-heuristics.json..."
bash tools/execute-tasks.sh "$INPUTS_FILE" --status-only >/dev/null 2>&1 || true

info "Running per-task runner..."
bash tools/run-execute-task.sh "$INPUTS_FILE"

CT_FILE="$SPEC_DIR/context/current-task.md"
ST_FILE="$SPEC_DIR/context/selected-technical.md"
SA_FILE="$SPEC_DIR/context/selected-api.md"
SD_FILE="$SPEC_DIR/context/selected-db.md"
LOG_FILE="$SPEC_DIR/debug/exec-trace/task-1.log"

[[ -f "$CT_FILE" ]] || fail "Missing current-task.md"
[[ -f "$ST_FILE" ]] || fail "Missing selected-technical.md"
[[ -f "$SA_FILE" ]] || fail "Missing selected-api.md"
[[ -f "$SD_FILE" ]] || fail "Missing selected-db.md"
[[ -f "$LOG_FILE" ]] || fail "Missing debug trace log"

grep -q '^## Greeting API feature' "$ST_FILE" && pass "Technical extract matched heading" || fail "Technical extract missing"
grep -q '^## Greeting API feature' "$SA_FILE" && pass "API extract matched heading" || fail "API extract missing"
grep -q '^## Greeting API feature' "$SD_FILE" && pass "DB extract matched heading" || fail "DB extract missing"

pass "run-execute-task selective-reading test completed"
