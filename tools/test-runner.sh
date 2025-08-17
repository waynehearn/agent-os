#!/usr/bin/env bash
# test-runner.sh - Minimal focused test runner (token-efficient, cross-platform)
#
# Usage:
#   tools/test-runner.sh --spec-folder <abs_path> --parent <number> [--pattern <glob_or_regex>]
#
# Behavior:
# - If $TEST_CMD is set, executes it and uses its exit code as success/failure
# - Otherwise, acts as a no-op success (returns 0)
# - Writes a compact summary to [spec]/context/test-run-summary.json
# - Avoids heavy logs; caller handles NDJSON trace lines

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log(){ echo -e "${BLUE}[test-runner]${NC} $*"; }
warn(){ echo -e "${YELLOW}[test-runner][WARN]${NC} $*" >&2; }
err(){ echo -e "${RED}[test-runner][ERROR]${NC} $*" >&2; }

now_iso(){ if date -u +%Y-%m-%dT%H:%M:%SZ >/dev/null 2>&1; then date -u +%Y-%m-%dT%H:%M:%SZ; else date +%Y-%m-%dT%H:%M:%SZ; fi }

SPEC_FOLDER=""; PARENT_NUM=""; PATTERN=""; RETRIES=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --spec-folder) SPEC_FOLDER="$2"; shift 2;;
    --parent) PARENT_NUM="$2"; shift 2;;
    --pattern) PATTERN="$2"; shift 2;;
  --retries) RETRIES="$2"; shift 2;;
    *) warn "Unknown arg: $1"; shift;;
  esac
endonecho

[[ -n "$SPEC_FOLDER" && -d "$SPEC_FOLDER" ]] || { err "Missing/invalid --spec-folder"; exit 2; }
[[ -n "$PARENT_NUM" ]] || { err "Missing --parent"; exit 2; }

CTX_DIR="$SPEC_FOLDER/context"; mkdir -p "$CTX_DIR"
OUT_JSON="$CTX_DIR/test-run-summary.json"

runner="noop"
attempts=0
start=$(date +%s)
rc=0

# Expose helpful env to TEST_CMD
export PARENT_TASK="$PARENT_NUM"
export PATTERN

if [[ -n "${TEST_CMD:-}" ]]; then
  runner="env:TEST_CMD"
  while :; do
    attempts=$(( attempts + 1 ))
    # shellcheck disable=SC2086
    bash -lc "$TEST_CMD" && { rc=0; break; } || rc=$?
    if [[ $attempts -gt ${RETRIES:-0} ]]; then
      break
    fi
    log "Retrying tests (attempt $((attempts+1)) of $((RETRIES+1)))..."
  done
else
  # no-op success
  rc=0; attempts=1
fi
end=$(date +%s)

# avoid negative duration if clock jumps
if [[ $end -lt $start ]]; then end=$start; fi

dur=$(( (end - start) * 1000 ))

ts=$(now_iso)
success=false; [[ $rc -eq 0 ]] && success=true
cat > "$OUT_JSON" <<JSON
{"updatedAt":"$ts","parentTask":$PARENT_NUM,"success":$success,"runner":"$runner","durationMs":$dur,"attempts":$attempts,"pattern":"$PATTERN"}
JSON

log "Wrote summary: $OUT_JSON (success=$success)"
exit $rc
