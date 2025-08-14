#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
verify-jq.sh
Checks that jq is available in PATH and prints its version.

Optionally, pass a spec folder path to confirm context/manifest.json presence:
  ./tools/verify-jq.sh @.agent-os/specs/YYYY-MM-DD-spec-name
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq not found in PATH. See docs/installation.md for install steps." >&2
  exit 127
fi

echo "jq version: $(jq --version)"

SPEC_PATH="${1:-}"
if [[ -n "$SPEC_PATH" ]]; then
  # Expand leading @ alias minimally for common shells; leave as-is if not matched
  case "$SPEC_PATH" in
    @.agent-os/*)
      # Relative to repo/project root; leave as-is for the caller's environment
      :
      ;;
    @~/*)
      # Home alias expansion
      SPEC_PATH="$HOME/${SPEC_PATH#@~/}"
      ;;
  esac

  MANIFEST="$SPEC_PATH/context/manifest.json"
  if [[ -f "$MANIFEST" ]]; then
    echo "Found manifest: $MANIFEST"
    # Validate JSON structure is at least parseable
    if jq empty "$MANIFEST" 2>/dev/null; then
      echo "Manifest JSON is valid."
    else
      echo "Warning: manifest exists but JSON is not valid." >&2
      exit 2
    fi
  else
    echo "Note: No manifest found at $MANIFEST (this is fine before first update)."
  fi
fi

exit 0
