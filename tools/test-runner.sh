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
done

[[ -n "$SPEC_FOLDER" && -d "$SPEC_FOLDER" ]] || { err "Missing/invalid --spec-folder"; exit 2; }
[[ -n "$PARENT_NUM" ]] || { err "Missing --parent"; exit 2; }

CTX_DIR="$SPEC_FOLDER/context"; mkdir -p "$CTX_DIR"
OUT_JSON="$CTX_DIR/test-run-summary.json"

# If no explicit pattern provided, derive a lightweight default from the parent task title
derive_pattern_from_title(){
  local snippet="$CTX_DIR/current-task.md"
  local tasks_file="$SPEC_FOLDER/tasks.md"
  local title=""
  if [[ -f "$snippet" ]]; then
    title=$(sed -n '1,3p' "$snippet" | grep -E '^## Task [0-9]+' | sed 's/^## Task [0-9][0-9]*: *//')
  elif [[ -f "$tasks_file" ]]; then
    title=$(grep -m1 "^## Task ${PARENT_NUM}:" "$tasks_file" | sed 's/^## Task [0-9][0-9]*: *//')
  fi
  title=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]/ /g')
  # choose first 1-2 words of length >=3 to keep the pattern compact
  local w1="" w2=""
  while IFS= read -r w; do
    [[ -z "$w1" && ${#w} -ge 3 ]] && { w1="$w"; continue; }
    [[ -z "$w2" && ${#w} -ge 3 ]] && { w2="$w"; break; }
  done < <(echo "$title" | tr ' ' '\n' | grep -E '.+')
  if [[ -n "$w1" && -n "$w2" ]]; then
    echo "${w1}.*${w2}"
  elif [[ -n "$w1" ]]; then
    echo "$w1"
  else
    echo ""
  fi
}

if [[ -z "$PATTERN" ]]; then
  PATTERN=$(derive_pattern_from_title || true)
fi

# Provide a files hint for common test layouts when not supplied by the user
derive_files_hint(){
  local root
  root=$(cd "$SPEC_FOLDER/.." && pwd)
  if [[ -d "$root/test" ]]; then echo "test/**/*"; return; fi
  if [[ -d "$root/tests" ]]; then echo "tests/**/*"; return; fi
  if [[ -d "$root/src/test" ]]; then echo "src/test/**/*"; return; fi
  echo "test/**/*"
}

FILES_HINT=${TEST_FILES_HINT:-}
if [[ -z "$FILES_HINT" ]]; then
  FILES_HINT=$(derive_files_hint)
fi

runner="noop"
attempts=0
start=$(date +%s)
rc=0

# Expose helpful env to TEST_CMD
export PARENT_TASK="$PARENT_NUM"
export PATTERN
export TEST_FILES_HINT="$FILES_HINT"

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
{"updatedAt":"$ts","parentTask":$PARENT_NUM,"success":$success,"runner":"$runner","durationMs":$dur,"attempts":$attempts,"pattern":"$PATTERN","filesHint":"$FILES_HINT"}
JSON

log "Wrote summary: $OUT_JSON (success=$success)"
exit $rc
