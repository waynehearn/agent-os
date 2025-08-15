#!/usr/bin/env bash
set -euo pipefail

# trace-tail.sh
# Tail and pretty-print NDJSON execution traces for Agent-OS.
# Usage:
#   tools/trace-tail.sh path/to/.agent-os/specs/YYYY-MM-DD-name/debug/exec-trace [--follow]
# Examples:
#   tools/trace-tail.sh ".agent-os/specs/2025-08-14-foo/debug/exec-trace" --follow
#
# Requirements: coreutils (tail)
# Optional: jq (for pretty output). Without jq, raw NDJSON lines are printed.

DIR="${1:-}"
FOLLOW="${2:-}"
if [[ -z "$DIR" ]]; then
  echo "Usage: $0 <exec-trace-dir> [--follow]" >&2
  exit 1
fi

HAVE_JQ=1
if ! command -v jq >/dev/null 2>&1; then
  HAVE_JQ=0
  echo "Note: jq not found. Falling back to raw NDJSON output." >&2
fi

print_line() {
  local line="$1"
  # Attempt to parse; if not JSON, print raw
  if [[ "$HAVE_JQ" -eq 1 ]] && echo "$line" | jq -e . >/dev/null 2>&1; then
    local ts step subagent action src parent task result status
    ts=$(echo "$line" | jq -r '.ts // ""')
    step=$(echo "$line" | jq -r '.step // ""')
    subagent=$(echo "$line" | jq -r '.subagent // ""')
    action=$(echo "$line" | jq -r '.action // ""')
    parent=$(echo "$line" | jq -r '.parentTask // ""')
    result=$(echo "$line" | jq -r '.result // ""')
    status=$(echo "$line" | jq -r '.status // ""')
    errors=$(echo "$line" | jq -r '.errors | select(.) | tostring // ""')

    # Color codes
    local DIM='\033[2m' RESET='\033[0m' GREEN='\033[32m' RED='\033[31m' CYAN='\033[36m' YELLOW='\033[33m'

    local tag=""
    if [[ -n "$subagent" ]]; then tag="[$subagent]"; fi
    if [[ "$action" == "response" && "$result" == "pass" ]]; then color="$GREEN"; msg="ok";
    elif [[ "$action" == "response" && "$result" == "fail" ]]; then color="$RED"; msg="fail";
    elif [[ "$action" == "request" ]]; then color="$CYAN"; msg="call";
    else color="$YELLOW"; msg="$action"; fi

    printf "%s%s step:%s parent:%s %s %s%s\n" \
      "$color" "$msg" "$step" "${parent:-}" "$tag" "$ts" "$RESET"

    # Print summarized fields
    echo "$line" | jq -r 'del(.ts) | del(.includeBodies) | del(.action) | del(.step) | del(.parentTask) | del(.result) | select(.!=null) | to_entries | map("  \(.key): \(.value)") | .[]' 2>/dev/null || true
  else
    # Raw fallback
    echo "$line"
  fi
}

consume_file() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  while IFS= read -r line; do
    print_line "$line"
  done < "$f"
}

if [[ "$FOLLOW" == "--follow" ]]; then
  # Combine session + task logs and follow updates in a simple loop
  echo "Following logs in $DIR (Ctrl-C to stop)" >&2
  while true; do
    for f in "$DIR"/*.log; do
      consume_file "$f"
    done
    sleep 1
  done
else
  # One-shot pretty print of existing logs
  for f in "$DIR"/*.log; do
    echo "--- $f ---"
    consume_file "$f"
  done
fi
