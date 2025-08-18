#!/usr/bin/env bash
set -euo pipefail

# Reports the latest spec context size and freshness
# Output (key=value):
#   LATEST=YYYY-MM-DD-<name>
#   CONTEXT_DIR=.agent-os/specs/<folder>/context
#   FILES=<count>
#   CHARS=<char_count>
#   TOKENS~=<approx tokens>
#   AGE=<human age>

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SPECS_DIR="$ROOT_DIR/.agent-os/specs"

if [[ ! -d "$SPECS_DIR" ]] || [[ -z $(ls -1 "$SPECS_DIR" 2>/dev/null || true) ]]; then
  echo "NO_SPECS"
  exit 0
fi

LATEST=$(ls -1 "$SPECS_DIR" | sort -r | head -n1)
CONTEXT_DIR="$SPECS_DIR/$LATEST/context"
if [[ ! -d "$CONTEXT_DIR" ]]; then
  echo "NO_CONTEXT|$LATEST"
  exit 0
fi

# File count
FILE_COUNT=$(find "$CONTEXT_DIR" -type f | wc -l | tr -d '\r')

# Character count (portable); ignore wc summary lines
CHAR_COUNT=$(find "$CONTEXT_DIR" -type f -exec wc -m {} + 2>/dev/null | awk '{s+=$1} END {print s+0}')
TOKENS=$(( CHAR_COUNT / 4 ))

# Newest modification time among files (portable)
NEWEST_EPOCH=0
while IFS= read -r -d '' f; do
  mt=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo 0)
  if (( mt > NEWEST_EPOCH )); then NEWEST_EPOCH=$mt; fi
done < <(find "$CONTEXT_DIR" -type f -print0)

NOW_EPOCH=$(date +%s)
if (( NEWEST_EPOCH > 0 )); then AGE_SEC=$(( NOW_EPOCH - NEWEST_EPOCH )); else AGE_SEC=0; fi
if (( AGE_SEC < 60 )); then AGE_HUMAN="${AGE_SEC}s";
elif (( AGE_SEC < 3600 )); then AGE_HUMAN="$((AGE_SEC/60))m";
elif (( AGE_SEC < 86400 )); then AGE_HUMAN="$((AGE_SEC/3600))h";
else AGE_HUMAN="$((AGE_SEC/86400))d"; fi

printf "LATEST=%s\nCONTEXT_DIR=%s\nFILES=%s\nCHARS=%s\nTOKENS~=%s\nAGE=%s\n" \
  "$LATEST" "$CONTEXT_DIR" "$FILE_COUNT" "$CHAR_COUNT" "$TOKENS" "$AGE_HUMAN"
